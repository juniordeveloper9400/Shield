import { randomUUID } from 'node:crypto';
import {
  BadGatewayException,
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { and, asc, desc, eq, gt, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  customerReviewVideo,
  homeBanner,
  membershipTier,
  order,
  paymentMethod,
  product,
  productCategory,
  productDetail,
  productFaq,
  productSubcategory,
  promo,
  shieldStore,
  users,
} from '../../db/schema';
import { CacheService } from '../../cache/cache.service';
import type { Env } from '../../config/env';
import { PUBLIC_MEDIA_STORAGE, type PublicMediaStorage } from '../../storage/public-media-storage';
import type {
  CreateCategoryDto,
  CreateProductDto,
  CreateReviewVideoDto,
  CreateReviewVideoUploadDto,
  CreateStoreDto,
  ListProductsQuery,
  UpdateCategoryDto,
  UpdateProductDto,
  UpdateReviewVideoDto,
  UpdateStoreDto,
} from './dto';

/** Where uploaded customer review clips live in the public bucket. */
const REVIEW_VIDEO_PREFIX = 'review-videos/';
const REVIEW_VIDEO_EXTENSIONS: Record<string, string> = {
  'video/mp4': 'mp4',
  'video/webm': 'webm',
  'video/quicktime': 'mov',
};

const formatMegabytes = (bytes: number) => `${(bytes / (1024 * 1024)).toFixed(bytes >= 10 * 1024 * 1024 ? 0 : 1)} MB`;

const TTL = {
  SHORT: 60, // frequently-touched lists
  LONG: 300, // near-static reference data
};

/**
 * Cache-aside on every read, invalidated on the matching write — this is
 * the template pattern backend/docs/build-playbook.md M2 calls for, reused
 * by every later read-heavy module. See backend/docs/trd.md for the
 * non-functional reasoning (catalogue is the highest-read-volume path).
 */
@Injectable()
export class CatalogueService {
  private readonly logger = new Logger(CatalogueService.name);

  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cache: CacheService,
    @Inject(PUBLIC_MEDIA_STORAGE) private readonly media: PublicMediaStorage,
    private readonly config: ConfigService<Env, true>,
  ) {}

  // ---- Stores -------------------------------------------------------------
  // NOTE: app.shield_store has no lat/lng columns in the live schema, so
  // "nearest to me" sorting is not implemented — see db/schema/app-catalogue.ts.

  async listStores() {
    return this.cache.getOrSet('catalogue:stores', TTL.LONG, () =>
      this.db.select().from(shieldStore).where(eq(shieldStore.isActive, true)).orderBy(asc(shieldStore.sort)),
    );
  }

  /**
   * Every branch, active or not, with live member/order counts — the
   * console's Stores page (`shieldweb/src/api/stores.ts`'s `listStores`,
   * migrated off direct Neon here). Not cached: an admin toggling a branch
   * needs to see the change immediately, and this list is read far less
   * often than the public storefront's.
   */
  async listStoresForStaff() {
    // Two plain queries merged in JS rather than a correlated subquery in
    // the select list — the same pg-mem incompatibility as
    // CareService.listLabCategories (a subquery-per-row select returns
    // garbage under the test DB), worked around the same way there.
    const stores = await this.db.select().from(shieldStore).orderBy(asc(shieldStore.sort), asc(shieldStore.name));
    if (stores.length === 0) return [];

    const memberCounts = await this.db
      .select({ storeId: users.homeStoreId, n: sql<number>`count(*)::int` })
      .from(users)
      .where(sql`${users.homeStoreId} IS NOT NULL AND ${users.deletedAt} IS NULL`)
      .groupBy(users.homeStoreId);
    const memberCountByStore = new Map(memberCounts.map((c) => [c.storeId, c.n]));

    const orderCounts = await this.db
      .select({ storeId: order.storeId, n: sql<number>`count(*)::int` })
      .from(order)
      .where(sql`${order.storeId} IS NOT NULL`)
      .groupBy(order.storeId);
    const orderCountByStore = new Map(orderCounts.map((c) => [c.storeId, c.n]));

    return stores.map((store) => ({
      ...store,
      memberCount: memberCountByStore.get(store.id) ?? 0,
      orderCount: orderCountByStore.get(store.id) ?? 0,
    }));
  }

  /** Returns `{ store: null }`, not a thrown error, when `dto.code` is
   *  already taken — mirrors the old direct-Neon `ON CONFLICT DO NOTHING
   *  RETURNING id` contract shieldweb's createStore already treats as "that
   *  code is taken" (see StoresPage.tsx's `if (!id) …`). Wrapped in an
   *  object rather than a bare null/row so the response shape doesn't
   *  change between the two outcomes. */
  async createStore(dto: CreateStoreDto) {
    // A pre-check rather than relying solely on ON CONFLICT DO NOTHING
    // RETURNING — pg-mem's test DB doesn't return an empty result on that
    // conflict the way real Postgres does, and this is easier to reason
    // about regardless. The insert is still guarded by the real unique
    // constraint (caught below) against a genuine race on production.
    const [existing] = await this.db.select({ id: shieldStore.id }).from(shieldStore).where(eq(shieldStore.code, dto.code)).limit(1);
    if (existing) return { store: null };

    const [last] = await this.db
      .select({ sort: shieldStore.sort })
      .from(shieldStore)
      .orderBy(desc(shieldStore.sort))
      .limit(1);
    const sort = last ? last.sort + 1 : 0;

    try {
      const [created] = await this.db
        .insert(shieldStore)
        .values({
          ...dto,
          latitude: dto.latitude?.toString() ?? null,
          longitude: dto.longitude?.toString() ?? null,
          sort,
        })
        .returning();
      await this.cache.invalidate('catalogue:stores');
      return { store: created };
    } catch {
      // Lost a race with a concurrent create of the same code — same "that
      // code is taken" outcome as the pre-check above (see StoresPage.tsx's
      // `if (!id) …`).
      return { store: null };
    }
  }

  async updateStore(id: number, dto: UpdateStoreDto) {
    const { latitude, longitude, ...rest } = dto;
    const [updated] = await this.db
      .update(shieldStore)
      .set({
        ...rest,
        ...(latitude !== undefined ? { latitude: latitude?.toString() ?? null } : {}),
        ...(longitude !== undefined ? { longitude: longitude?.toString() ?? null } : {}),
      })
      .where(eq(shieldStore.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Branch not found' } });
    await this.cache.invalidate('catalogue:stores');
    return updated;
  }

  async setStoreActive(id: number, isActive: boolean) {
    const [updated] = await this.db
      .update(shieldStore)
      .set({ isActive })
      .where(eq(shieldStore.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Branch not found' } });
    await this.cache.invalidate('catalogue:stores');
    return updated;
  }

  /** Migration 0057 — off drops the branch from the lab checkout's own
   *  branch picker in both apps (`BookingService.listLabStores`); does not
   *  touch `isActive` at all. */
  async setStoreOffersLab(id: number, offersLabCollection: boolean) {
    const [updated] = await this.db
      .update(shieldStore)
      .set({ offersLabCollection })
      .where(eq(shieldStore.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Branch not found' } });
    await this.cache.invalidate('catalogue:stores');
    return updated;
  }

  // ---- Membership tiers -----------------------------------------------------
  // Reference data for resolving a tier kind (silver/gold/platinum) to the
  // id `POST /v1/member/wallet/cards` requires — the load-amount presets
  // themselves are bundled client-side already (see
  // `shield agent_invester/lib/module/privilege/privilege_tier.dart`), so
  // this only needs to expose id/kind/name, not membership_tier_load.

  async listMembershipTiers() {
    return this.cache.getOrSet('catalogue:membership-tiers', TTL.LONG, () =>
      this.db.select().from(membershipTier).orderBy(asc(membershipTier.sort)),
    );
  }

  // ---- Payment methods --------------------------------------------------
  // Checkout's option list — previously had no mirror or route at all, so
  // `order.paymentMethodId` had nothing a client could validate against or
  // even list.

  async listPaymentMethods() {
    return this.cache.getOrSet('catalogue:payment-methods', TTL.LONG, () =>
      this.db.select().from(paymentMethod).where(eq(paymentMethod.isLive, true)).orderBy(asc(paymentMethod.sort)),
    );
  }

  // ---- Categories -----------------------------------------------------------

  async listCategories() {
    return this.cache.getOrSet('catalogue:categories', TTL.LONG, () =>
      this.db
        .select()
        .from(productCategory)
        .where(eq(productCategory.isActive, true))
        .orderBy(asc(productCategory.sort)),
    );
  }

  async listSubcategories(categoryId: number) {
    return this.cache.getOrSet(`catalogue:subcategories:${categoryId}`, TTL.LONG, () =>
      this.db
        .select()
        .from(productSubcategory)
        .where(eq(productSubcategory.categoryId, categoryId))
        .orderBy(asc(productSubcategory.sort)),
    );
  }

  async createCategory(dto: CreateCategoryDto) {
    const [created] = await this.db.insert(productCategory).values(dto).returning();
    await this.cache.invalidate('catalogue:categories');
    return created;
  }

  async updateCategory(id: number, dto: UpdateCategoryDto) {
    const [updated] = await this.db
      .update(productCategory)
      .set(dto)
      .where(eq(productCategory.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Category not found' } });
    await this.cache.invalidate('catalogue:categories', 'catalogue:subcategories:*');
    return updated;
  }

  // ---- Products ---------------------------------------------------------

  async listProducts(query: ListProductsQuery) {
    const key = `catalogue:products:${query.categoryId ?? 'all'}:${query.subcategoryId ?? 'all'}:${query.cursor ?? 'start'}:${query.limit}`;
    return this.cache.getOrSet(key, TTL.SHORT, async () => {
      const conditions = [eq(product.status, 'ACTIVE')];
      if (query.categoryId) conditions.push(eq(product.categoryId, query.categoryId));
      if (query.subcategoryId) conditions.push(eq(product.subcategoryId, query.subcategoryId));
      if (query.cursor) conditions.push(gt(product.id, query.cursor));

      const rows = await this.db
        .select()
        .from(product)
        .where(and(...conditions))
        .orderBy(asc(product.id))
        .limit(query.limit);

      return { items: rows, nextCursor: rows.length === query.limit ? rows[rows.length - 1].id : null };
    });
  }

  async getProduct(id: number) {
    return this.cache.getOrSet(`catalogue:product:${id}`, TTL.LONG, async () => {
      const [row] = await this.db.select().from(product).where(eq(product.id, id)).limit(1);
      if (!row) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not found' } });

      const [detail] = await this.db.select().from(productDetail).where(eq(productDetail.productId, id)).limit(1);
      const faqs = await this.db
        .select()
        .from(productFaq)
        .where(eq(productFaq.productId, id))
        .orderBy(asc(productFaq.sort));

      return { ...row, detail: detail ?? null, faqs };
    });
  }

  async createProduct(dto: CreateProductDto) {
    const [created] = await this.db
      .insert(product)
      .values({ ...dto, price: dto.price.toString(), mrp: dto.mrp.toString(), stockQuantity: dto.stockQuantity.toString() })
      .returning();
    await this.cache.invalidate('catalogue:products:*');
    return created;
  }

  async updateProduct(id: number, dto: UpdateProductDto) {
    const { price, mrp, stockQuantity, ...rest } = dto;
    const [updated] = await this.db
      .update(product)
      .set({
        ...rest,
        ...(price !== undefined ? { price: price.toString() } : {}),
        ...(mrp !== undefined ? { mrp: mrp.toString() } : {}),
        ...(stockQuantity !== undefined ? { stockQuantity: stockQuantity.toString() } : {}),
      })
      .where(eq(product.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not found' } });
    await this.cache.invalidate('catalogue:products:*', `catalogue:product:${id}`);
    return updated;
  }

  // ---- Content: banners, promos ------------------------------------------

  async listBanners() {
    return this.cache.getOrSet('catalogue:banners', TTL.SHORT, () =>
      this.db.select().from(homeBanner).where(eq(homeBanner.isActive, true)).orderBy(asc(homeBanner.sort)),
    );
  }

  async listPromos() {
    return this.cache.getOrSet('catalogue:promos', TTL.SHORT, () =>
      this.db.select().from(promo).where(eq(promo.isActive, true)).orderBy(asc(promo.sort)),
    );
  }

  // ---- Content: customer review videos ------------------------------------
  // Public members see only active clips; the console (staff) manages every
  // clip, active or not — see shieldweb/src/api/customerReviewVideos.ts.

  async listActiveReviewVideos() {
    return this.cache.getOrSet('catalogue:review-videos:active', TTL.SHORT, () =>
      this.db
        .select()
        .from(customerReviewVideo)
        .where(eq(customerReviewVideo.isActive, true))
        .orderBy(asc(customerReviewVideo.sort)),
    );
  }

  async listAllReviewVideosForStaff() {
    return this.db.select().from(customerReviewVideo).orderBy(asc(customerReviewVideo.sort));
  }

  /** Inserts after the current last clip unless an explicit sort is given — matches the console's existing behavior. */
  async createReviewVideo(dto: CreateReviewVideoDto) {
    let sort = dto.sort;
    if (sort === undefined) {
      const [last] = await this.db
        .select({ sort: customerReviewVideo.sort })
        .from(customerReviewVideo)
        .orderBy(desc(customerReviewVideo.sort))
        .limit(1);
      sort = last ? last.sort + 1 : 0;
    }
    const [created] = await this.db.insert(customerReviewVideo).values({ ...dto, sort }).returning();
    await this.cache.invalidate('catalogue:review-videos:active');
    return created;
  }

  /**
   * A single-use signed upload link the console sends a clip to directly —
   * the file never passes through this API. The clip lands in the public
   * bucket under a random key, and `publicUrl` is what gets saved as the
   * clip's `videoUrl` once the upload succeeds.
   */
  async createReviewVideoUpload(dto: CreateReviewVideoUploadDto) {
    if (!this.media.isConfigured()) {
      throw new ServiceUnavailableException({
        error: {
          code: 'STORAGE_NOT_CONFIGURED',
          message:
            'Video storage is not set up yet. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (and the bucket) on the API first.',
        },
      });
    }
    // Checked here, before any upload, so an oversized file fails in a second
    // instead of after minutes of uploading to be refused by Supabase.
    const maxBytes = Math.round(this.config.get('REVIEW_VIDEO_MAX_MB', { infer: true }) * 1024 * 1024);
    if (dto.size > maxBytes) {
      throw new BadRequestException({
        error: {
          code: 'VIDEO_TOO_LARGE',
          message: `That video is ${formatMegabytes(dto.size)}; the limit is ${formatMegabytes(maxBytes)}. Compress it, or raise the limit (REVIEW_VIDEO_MAX_MB and the Supabase bucket's own limit).`,
        },
      });
    }
    const key = `${REVIEW_VIDEO_PREFIX}${randomUUID()}.${REVIEW_VIDEO_EXTENSIONS[dto.contentType]}`;
    try {
      return await this.media.createUpload({ key });
    } catch (error) {
      this.logger.error(`Could not create a review video upload link: ${String(error)}`);
      throw new BadGatewayException({
        error: {
          code: 'STORAGE_UNAVAILABLE',
          message: error instanceof Error ? error.message : 'The storage service is unavailable.',
        },
      });
    }
  }

  /**
   * Removes an uploaded clip from the bucket — when a clip is deleted or its
   * video replaced, or an upload is abandoned. Only ever deletes objects under
   * this feature's own prefix in our own public bucket; any other URL (a
   * legacy YouTube link, a bundled asset path) is ignored, not an error.
   */
  async deleteReviewVideoMedia(url: string): Promise<{ deleted: boolean }> {
    if (!this.media.isConfigured()) return { deleted: false };
    const key = this.media.keyFromPublicUrl(url);
    if (!key || !key.startsWith(REVIEW_VIDEO_PREFIX)) return { deleted: false };
    await this.media.delete(key);
    return { deleted: true };
  }

  /** Best-effort clean-up: a failed delete of an orphaned file must never fail the write that made it orphaned. */
  private async discardMedia(url: string | null | undefined) {
    if (!url) return;
    try {
      await this.deleteReviewVideoMedia(url);
    } catch (error) {
      this.logger.warn(`Could not delete replaced review video ${url}: ${String(error)}`);
    }
  }

  async updateReviewVideo(id: number, dto: UpdateReviewVideoDto) {
    const [before] = dto.videoUrl
      ? await this.db
          .select({ videoUrl: customerReviewVideo.videoUrl })
          .from(customerReviewVideo)
          .where(eq(customerReviewVideo.id, id))
          .limit(1)
      : [];
    const [updated] = await this.db
      .update(customerReviewVideo)
      .set(dto)
      .where(eq(customerReviewVideo.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Review video not found' } });
    await this.cache.invalidate('catalogue:review-videos:active');
    if (before && before.videoUrl !== updated.videoUrl) await this.discardMedia(before.videoUrl);
    return updated;
  }

  async deleteReviewVideo(id: number) {
    const [deleted] = await this.db.delete(customerReviewVideo).where(eq(customerReviewVideo.id, id)).returning();
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Review video not found' } });
    await this.cache.invalidate('catalogue:review-videos:active');
    await this.discardMedia(deleted.videoUrl);
  }
}
