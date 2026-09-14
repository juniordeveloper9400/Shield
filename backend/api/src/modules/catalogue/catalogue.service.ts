import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, asc, desc, eq, gt } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  customerReviewVideo,
  homeBanner,
  membershipTier,
  product,
  productCategory,
  productDetail,
  productFaq,
  productSubcategory,
  promo,
  shieldStore,
} from '../../db/schema';
import { CacheService } from '../../cache/cache.service';
import type {
  CreateCategoryDto,
  CreateProductDto,
  CreateReviewVideoDto,
  ListProductsQuery,
  UpdateCategoryDto,
  UpdateProductDto,
  UpdateReviewVideoDto,
} from './dto';

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
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cache: CacheService,
  ) {}

  // ---- Stores -------------------------------------------------------------
  // NOTE: app.shield_store has no lat/lng columns in the live schema, so
  // "nearest to me" sorting is not implemented — see db/schema/app-catalogue.ts.

  async listStores() {
    return this.cache.getOrSet('catalogue:stores', TTL.LONG, () =>
      this.db.select().from(shieldStore).where(eq(shieldStore.isActive, true)).orderBy(asc(shieldStore.sort)),
    );
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

  async updateReviewVideo(id: number, dto: UpdateReviewVideoDto) {
    const [updated] = await this.db
      .update(customerReviewVideo)
      .set(dto)
      .where(eq(customerReviewVideo.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Review video not found' } });
    await this.cache.invalidate('catalogue:review-videos:active');
    return updated;
  }

  async deleteReviewVideo(id: number) {
    const [deleted] = await this.db.delete(customerReviewVideo).where(eq(customerReviewVideo.id, id)).returning();
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Review video not found' } });
    await this.cache.invalidate('catalogue:review-videos:active');
  }
}
