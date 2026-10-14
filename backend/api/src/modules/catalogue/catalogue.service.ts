import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { and, asc, desc, eq, gt, sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import {
  brand,
  customerReviewVideo,
  homeBanner,
  membershipTier,
  order,
  paymentMethod,
  product,
  productCategory,
  productDetail,
  productFaq,
  productImage,
  productSubcategory,
  promo,
  shieldStore,
  users,
} from '../../db/schema';
import { CacheService } from '../../cache/cache.service';
import type {
  CreateBannerDto,
  CreateBrandDto,
  CreateCategoryDto,
  CreateProductDto,
  CreateReviewVideoDto,
  CreateStoreDto,
  CreateSubcategoryDto,
  ListProductsQuery,
  RenameBrandDto,
  SetProductStatusDto,
  UpdateBannerDto,
  UpdateCategoryDto,
  UpdateProductDto,
  UpdateProductSectionsDto,
  UpdateReviewVideoDto,
  UpdateStoreDto,
  UpdateSubcategoryDto,
} from './dto';
import { ReviewVideoMediaService, reviewVideoMediaIdFromUrl } from './review-video-media.service';

/** Where uploaded customer review clips live in the public bucket. */
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
    private readonly reviewVideoMedia: ReviewVideoMediaService,
  ) {}

  // ---- Stores -------------------------------------------------------------
  // NOTE: app.shield_store has no lat/lng columns in the live schema, so
  // "nearest to me" sorting is not implemented — see db/schema/app-catalogue.ts.

  /**
   * Deliberately not `select()` (every column): `shieldStore` also carries
   * each branch's settlement bank account (`bankAccountName`/
   * `bankAccountNumber`/`bankIfsc`/`bankName`) — real banking details that
   * have no reason to be handed to an unauthenticated caller for every
   * branch at once just to render a public store list. A member who needs
   * to see *their own order's* branch's bank details for a manual transfer
   * gets them from [getStoreBankDetails] instead, scoped to that one store.
   */
  /**
   * The admin WhatsApp number the apps offer when a member has no store to
   * message yet. Set in the admin console (app.app_setting, migration 0073).
   * Blank until it has been set — the apps then hide that option.
   */
  async contactSettings(): Promise<{ adminWhatsapp: string }> {
    const rows = (await this.db.execute(
      sql`SELECT value FROM app.app_setting WHERE key = 'admin_whatsapp' LIMIT 1`,
    )) as unknown as { value: string }[];
    return { adminWhatsapp: (rows[0]?.value ?? '').trim() };
  }

  async listStores() {
    return this.cache.getOrSet('catalogue:stores', TTL.LONG, () =>
      this.db
        .select({
          id: shieldStore.id,
          uuid: shieldStore.uuid,
          code: shieldStore.code,
          name: shieldStore.name,
          area: shieldStore.area,
          city: shieldStore.city,
          state: shieldStore.state,
          pincode: shieldStore.pincode,
          phone: shieldStore.phone,
          hours: shieldStore.hours,
          isActive: shieldStore.isActive,
          offersLabCollection: shieldStore.offersLabCollection,
          latitude: shieldStore.latitude,
          longitude: shieldStore.longitude,
          mapsUrl: shieldStore.mapsUrl,
          sort: shieldStore.sort,
        })
        .from(shieldStore)
        .where(eq(shieldStore.isActive, true))
        .orderBy(asc(shieldStore.sort)),
    );
  }

  /**
   * One active branch's settlement bank account, by its stable `code` — the
   * manual-bank-transfer details checkout shows for the specific branch an
   * order is with. Scoped to exactly one store rather than [listStores]'s
   * bulk read, which deliberately excludes these fields — see that
   * method's own doc. 404s for an unknown or inactive code rather than a
   * silent empty object, so the caller can tell "no such branch" apart
   * from "this branch just hasn't filled its bank details in yet" (blank
   * strings, same as the console leaves them until filled in).
   */
  async getStoreBankDetails(code: string) {
    const [store] = await this.db
      .select({
        bankAccountName: shieldStore.bankAccountName,
        bankAccountNumber: shieldStore.bankAccountNumber,
        bankIfsc: shieldStore.bankIfsc,
        bankName: shieldStore.bankName,
      })
      .from(shieldStore)
      .where(and(eq(shieldStore.code, code), eq(shieldStore.isActive, true)))
      .limit(1);
    if (!store) {
      throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'No active branch with that code' } });
    }
    return store;
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

  /** Every category, active or not, with its subcategories nested — the
   *  console's own Categories page, which shows everything; [listCategories]
   *  above (and the public route it backs) only ever returns the active
   *  ones. */
  async listCategoryGroupsForStaff() {
    const categories = await this.db.select().from(productCategory).orderBy(asc(productCategory.sort), asc(productCategory.id));
    const subcategories = await this.db
      .select()
      .from(productSubcategory)
      .orderBy(asc(productSubcategory.sort), asc(productSubcategory.id));
    const byCategory = new Map<number, typeof subcategories>();
    for (const sub of subcategories) {
      const list = byCategory.get(sub.categoryId) ?? [];
      list.push(sub);
      byCategory.set(sub.categoryId, list);
    }
    return categories.map((c) => ({ ...c, subcategories: byCategory.get(c.id) ?? [] }));
  }

  async createCategory(dto: CreateCategoryDto) {
    // Same pre-check-then-catch shape as createStore's own slug-equivalent
    // (its `code`) — see that method's own doc for why both are needed.
    const [existing] = await this.db.select({ id: productCategory.id }).from(productCategory).where(eq(productCategory.slug, dto.slug)).limit(1);
    if (existing) return { category: null };

    try {
      const [created] = await this.db.insert(productCategory).values(dto).returning();
      await this.cache.invalidate('catalogue:categories');
      return { category: created };
    } catch {
      return { category: null };
    }
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

  async setCategoryActive(id: number, isActive: boolean) {
    const [updated] = await this.db.update(productCategory).set({ isActive }).where(eq(productCategory.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Category not found' } });
    await this.cache.invalidate('catalogue:categories');
    return updated;
  }

  async setCategorySort(id: number, sort: number) {
    const [updated] = await this.db.update(productCategory).set({ sort }).where(eq(productCategory.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Category not found' } });
    await this.cache.invalidate('catalogue:categories');
    return updated;
  }

  async createSubcategory(categoryId: number, dto: CreateSubcategoryDto) {
    const [created] = await this.db.insert(productSubcategory).values({ ...dto, categoryId }).returning();
    await this.cache.invalidate(`catalogue:subcategories:${categoryId}`);
    return created;
  }

  async updateSubcategory(id: number, dto: UpdateSubcategoryDto) {
    const [updated] = await this.db.update(productSubcategory).set(dto).where(eq(productSubcategory.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Subcategory not found' } });
    await this.cache.invalidate(`catalogue:subcategories:${updated.categoryId}`);
    return updated;
  }

  /** `app.product.subcategory_id` is `ON DELETE SET NULL` — a product filed
   *  under this subcategory is cleared, not blocked, by its removal. */
  async deleteSubcategory(id: number) {
    const [deleted] = await this.db.delete(productSubcategory).where(eq(productSubcategory.id, id)).returning();
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Subcategory not found' } });
    await this.cache.invalidate(`catalogue:subcategories:${deleted.categoryId}`);
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

/** `app.product.category_id` by slug — the console picks a category by
   *  slug (the same value its dropdowns are keyed on), not the bigint id
   *  only the DB knows. */
  private async resolveCategoryId(slug: string): Promise<number> {
    const [row] = await this.db.select({ id: productCategory.id }).from(productCategory).where(eq(productCategory.slug, slug)).limit(1);
    if (!row) throw new BadRequestException({ error: { code: 'BAD_REQUEST', message: `Unknown category "${slug}"` } });
    return row.id;
  }

  /** Writes `app.product_detail` + `app.product_faq` for a product id —
   *  shared by createProduct and updateProduct, same upsert-then-replace
   *  shape shieldweb's own direct-SQL version used. */
  private async writeProductDetail(productId: number, d: CreateProductDto['detail']): Promise<void> {
    const lines = (value: string) => value.split('\n').map((line) => line.trim()).filter(Boolean);
    await this.db
      .insert(productDetail)
      .values({
        productId,
        form: d.form.trim(),
        manufacturer: d.manufacturer.trim(),
        description: d.description.trim(),
        ingredients: d.ingredients.trim(),
        storage: d.storage.trim(),
        highlights: lines(d.highlights),
        benefits: lines(d.benefits),
        directions: lines(d.directions),
        safety: lines(d.safety),
        updatedAt: new Date(),
      })
      .onConflictDoUpdate({
        target: productDetail.productId,
        set: {
          form: d.form.trim(),
          manufacturer: d.manufacturer.trim(),
          description: d.description.trim(),
          ingredients: d.ingredients.trim(),
          storage: d.storage.trim(),
          highlights: lines(d.highlights),
          benefits: lines(d.benefits),
          directions: lines(d.directions),
          safety: lines(d.safety),
          updatedAt: new Date(),
        },
      });

    await this.db.delete(productFaq).where(eq(productFaq.productId, productId));
    const faqs = d.faqs.filter((f) => f.question.trim() && f.answer.trim());
    if (faqs.length > 0) {
      await this.db
        .insert(productFaq)
        .values(faqs.map((f, i) => ({ productId, question: f.question.trim(), answer: f.answer.trim(), sort: i })));
    }
  }

  /** Replaces a product's whole image gallery — index 0 is the primary,
   *  mirrored onto `app.product.image` by the caller. */
  private async writeProductImages(productId: number, images: string[]): Promise<void> {
    await this.db.delete(productImage).where(eq(productImage.productId, productId));
    if (images.length > 0) {
      await this.db.insert(productImage).values(images.map((image, i) => ({ productId, image, sort: i })));
    }
  }

  // ---- Products: staff ----------------------------------------------------
  // Everything below is the console's own catalogue management — every
  // product regardless of status, plus the detail/gallery/brand writes
  // [listProducts]/[getProduct] above (member-facing, cached, ACTIVE-only)
  // never needed.

  /** Every product, any status, for the console's own table — joined with
   *  its category/subcategory names the way the old direct-SQL version's
   *  own LEFT JOINs did. Not cached: an admin editing a row expects to see
   *  the edit reflected immediately, not after TTL.SHORT. */
  async listProductsForStaff() {
    const rows = await this.db
      .select({
        id: product.id,
        code: product.code,
        name: product.name,
        pack: product.pack,
        brand: product.brand,
        categorySlug: productCategory.slug,
        categoryTitle: productCategory.title,
        subcategoryId: productSubcategory.id,
        subcategoryLabel: productSubcategory.label,
        price: product.price,
        mrp: product.mrp,
        discountLabel: product.discountLabel,
        isPrescriptionOnly: product.isPrescriptionOnly,
        status: product.status,
        stockQuantity: product.stockQuantity,
        image: product.image,
        isPopular: product.isPopular,
        isDeal: product.isDeal,
        isOfferOfDay: product.isOfferOfDay,
        createdAt: product.createdAt,
      })
      .from(product)
      .leftJoin(productCategory, eq(productCategory.id, product.categoryId))
      .leftJoin(productSubcategory, eq(productSubcategory.id, product.subcategoryId))
      .orderBy(asc(product.name));
    return rows;
  }

  async createProduct(dto: CreateProductDto) {
    const categoryId = await this.resolveCategoryId(dto.categorySlug);
    const [created] = await this.db
      .insert(product)
      .values({
        code: dto.code || null,
        name: dto.name,
        pack: dto.pack,
        brand: dto.brand || null,
        categoryId,
        subcategoryId: dto.subcategoryId ? Number(dto.subcategoryId) : null,
        price: dto.price.toString(),
        mrp: dto.mrp.toString(),
        discountLabel: dto.discountLabel,
        isPrescriptionOnly: dto.isPrescriptionOnly,
        status: dto.status === 'active' ? 'ACTIVE' : 'INACTIVE',
        stockQuantity: dto.stockQuantity.toString(),
        image: dto.image || null,
        isPopular: dto.isPopular,
        isDeal: dto.isDeal,
        isOfferOfDay: dto.isOfferOfDay,
      })
      .returning();

    // Best-effort, same as shieldweb's own direct-SQL version: a failure
    // here should not lose the product row that was just created.
    try {
      await this.writeProductDetail(created.id, dto.detail);
    } catch (err) {
      this.logger.error(`Product ${created.id} created, but its detail page failed to save`, err as Error);
    }
    const gallery = [dto.image, ...dto.extraImages].filter((img) => img.trim());
    if (gallery.length > 0) {
      try {
        await this.writeProductImages(created.id, gallery);
      } catch (err) {
        this.logger.error(`Product ${created.id} created, but its image gallery failed to save`, err as Error);
      }
    }

    await this.cache.invalidate('catalogue:products:*');
    return created;
  }

  /** Rewrites every admin-editable field of a product — core fields plus
   *  the detail page and FAQs, always together (the console's own "Edit"
   *  page always submits both), unlike [updateProduct]'s narrower partial
   *  patch. */
  async updateProductFull(id: number, dto: CreateProductDto) {
    await this.updateProduct(id, dto);
    await this.writeProductDetail(id, dto.detail);
    const gallery = [dto.image, ...dto.extraImages].filter((img) => img.trim());
    await this.writeProductImages(id, gallery);
  }

  async updateProduct(id: number, dto: UpdateProductDto) {
    const { price, mrp, stockQuantity, categorySlug, subcategoryId, status, detail: _detail, extraImages: _extraImages, ...rest } = dto;
    const [updated] = await this.db
      .update(product)
      .set({
        ...rest,
        ...(price !== undefined ? { price: price.toString() } : {}),
        ...(mrp !== undefined ? { mrp: mrp.toString() } : {}),
        ...(stockQuantity !== undefined ? { stockQuantity: stockQuantity.toString() } : {}),
        ...(categorySlug !== undefined ? { categoryId: await this.resolveCategoryId(categorySlug) } : {}),
        ...(subcategoryId !== undefined ? { subcategoryId: subcategoryId ? Number(subcategoryId) : null } : {}),
        ...(status !== undefined ? { status: status === 'active' ? 'ACTIVE' : 'INACTIVE' } : {}),
      })
      .where(eq(product.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not found' } });
    await this.cache.invalidate('catalogue:products:*', `catalogue:product:${id}`);
    return updated;
  }

  /** The detail-page content for a product, with every list field joined
   *  back into one newline-separated block for the console's own textarea
   *  fields — shieldweb's own `getProductDetail` shape. */
  async getProductDetailForStaff(id: number) {
    const [row] = await this.db.select().from(product).where(eq(product.id, id)).limit(1);
    if (!row) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not found' } });
    const [detail] = await this.db.select().from(productDetail).where(eq(productDetail.productId, id)).limit(1);
    const faqs = await this.db.select().from(productFaq).where(eq(productFaq.productId, id)).orderBy(asc(productFaq.sort));
    const images = await this.db.select().from(productImage).where(eq(productImage.productId, id)).orderBy(asc(productImage.sort));
    const hasDetail = detail != null && (Boolean(detail.form) || Boolean(detail.manufacturer) || Boolean(detail.description) || faqs.length > 0);
    return {
      form: detail?.form ?? '',
      manufacturer: detail?.manufacturer ?? '',
      description: detail?.description ?? '',
      ingredients: detail?.ingredients ?? '',
      storage: detail?.storage ?? '',
      highlights: (detail?.highlights ?? []).join('\n'),
      benefits: (detail?.benefits ?? []).join('\n'),
      directions: (detail?.directions ?? []).join('\n'),
      safety: (detail?.safety ?? []).join('\n'),
      faqs: faqs.map((f) => ({ question: f.question, answer: f.answer })),
      hasDetail,
      // Index 0 of the gallery is always the primary image (mirrored onto
      // app.product.image already) — "extra" means everything past it.
      extraImages: images.slice(1).map((i) => i.image),
    };
  }

  /** Removes a product from the catalogue. Order lines keep their text
   *  copy (`order_line.product_id` is `ON DELETE SET NULL`); the detail
   *  page, FAQs and gallery all cascade with it. */
  async deleteProductForStaff(id: number) {
    const [deleted] = await this.db.delete(product).where(eq(product.id, id)).returning();
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not found' } });
    await this.cache.invalidate('catalogue:products:*', `catalogue:product:${id}`);
  }

  async setProductStatus(id: number, dto: SetProductStatusDto) {
    const [updated] = await this.db
      .update(product)
      .set({ status: dto.status === 'active' ? 'ACTIVE' : 'INACTIVE' })
      .where(eq(product.id, id))
      .returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not found' } });
    await this.cache.invalidate('catalogue:products:*', `catalogue:product:${id}`);
    return updated;
  }

  /** Which home-feed rows a product appears in — Popular Items, Deals You
   *  Love, Offer of the Day. The app picks the change up on its next
   *  catalogue load. */
  async updateProductSections(id: number, dto: UpdateProductSectionsDto) {
    const [updated] = await this.db.update(product).set(dto).where(eq(product.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not found' } });
    await this.cache.invalidate('catalogue:products:*', `catalogue:product:${id}`);
    return updated;
  }

  // ---- Brands -------------------------------------------------------------
  // The Add/Edit Product form's Brand field picks from this instead of free
  // text, so the same brand reads the same way twice. `app.product.brand`
  // itself stays free text either way — renaming/deleting an entry here
  // never touches products already saved with that brand.

  async listBrands() {
    return this.db.select().from(brand).orderBy(asc(brand.name));
  }

  /** Registers a new brand, or returns the existing one — matched
   *  case-insensitively, so "Cetaphil" typed twice is one brand, not two.
   *  Same pre-check-then-catch shape as createCategory's own slug
   *  equivalent, for the same race-safety reason. */
  async createBrand(dto: CreateBrandDto) {
    const trimmed = dto.name.trim();
    const [existing] = await this.db.select().from(brand).where(sql`lower(${brand.name}) = lower(${trimmed})`).limit(1);
    if (existing) return existing;
    try {
      const [created] = await this.db.insert(brand).values({ name: trimmed }).returning();
      return created;
    } catch {
      const [raceWinner] = await this.db.select().from(brand).where(sql`lower(${brand.name}) = lower(${trimmed})`).limit(1);
      if (raceWinner) return raceWinner;
      throw new BadRequestException({ error: { code: 'BAD_REQUEST', message: 'Could not create this brand.' } });
    }
  }

  async renameBrand(id: number, dto: RenameBrandDto) {
    const [updated] = await this.db.update(brand).set({ name: dto.name.trim() }).where(eq(brand.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Brand not found' } });
    return updated;
  }

  /** Removes a brand from the list. Products keep their brand text as-is. */
  async deleteBrand(id: number) {
    await this.db.delete(brand).where(eq(brand.id, id));
  }

  // ---- Content: banners, promos ------------------------------------------

  /**
   * A placement's own swipeable banner strip (migration 0069) — `'home'`
   * (the original hero carousel) unless the caller asks for another, e.g.
   * `'lab'` for the Lab section's strip. One cache key per placement so
   * publishing a Lab banner never invalidates Home's.
   */
  async listBanners(placement: string = 'home') {
    return this.cache.getOrSet(`catalogue:banners:${placement}`, TTL.SHORT, () =>
      this.db
        .select()
        .from(homeBanner)
        .where(and(eq(homeBanner.isActive, true), eq(homeBanner.placement, placement)))
        .orderBy(asc(homeBanner.sort)),
    );
  }

  /** Every banner on one placement's strip, active or not — the console's
   *  own Banners page, which shows everything, not just what members see. */
  async listBannersForStaff(placement: string = 'home') {
    return this.db
      .select()
      .from(homeBanner)
      .where(eq(homeBanner.placement, placement))
      .orderBy(asc(homeBanner.sort), asc(homeBanner.id));
  }

  async createBanner(dto: CreateBannerDto) {
    const { sort, ...rest } = dto;
    let resolvedSort = sort;
    if (resolvedSort === undefined) {
      const [last] = await this.db
        .select({ sort: homeBanner.sort })
        .from(homeBanner)
        .where(eq(homeBanner.placement, dto.placement))
        .orderBy(desc(homeBanner.sort))
        .limit(1);
      resolvedSort = (last?.sort ?? -1) + 1;
    }
    const [created] = await this.db.insert(homeBanner).values({ ...rest, sort: resolvedSort }).returning();
    await this.cache.invalidate(`catalogue:banners:${dto.placement}`);
    return created;
  }

  async updateBanner(id: number, dto: UpdateBannerDto) {
    const [updated] = await this.db.update(homeBanner).set(dto).where(eq(homeBanner.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Banner not found' } });
    await this.cache.invalidate(`catalogue:banners:${updated.placement}`);
    return updated;
  }

  async setBannerSort(id: number, sort: number) {
    const [updated] = await this.db.update(homeBanner).set({ sort }).where(eq(homeBanner.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Banner not found' } });
    await this.cache.invalidate(`catalogue:banners:${updated.placement}`);
    return updated;
  }

  async setBannerActive(id: number, isActive: boolean) {
    const [updated] = await this.db.update(homeBanner).set({ isActive }).where(eq(homeBanner.id, id)).returning();
    if (!updated) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Banner not found' } });
    await this.cache.invalidate(`catalogue:banners:${updated.placement}`);
    return updated;
  }

  async deleteBanner(id: number) {
    const [deleted] = await this.db.delete(homeBanner).where(eq(homeBanner.id, id)).returning();
    if (!deleted) throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Banner not found' } });
    await this.cache.invalidate(`catalogue:banners:${deleted.placement}`);
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
    await this.assertReadyReviewVideo(dto.videoUrl);
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
  /**
   * Removes an uploaded clip from the bucket — when a clip is deleted or its
   * video replaced, or an upload is abandoned. Only ever deletes objects under
   * this feature's own prefix in our own public bucket; any other URL (a
   * legacy YouTube link, a bundled asset path) is ignored, not an error.
   */
  /** Best-effort clean-up: a failed delete of an orphaned file must never fail the write that made it orphaned. */
  private async discardMedia(url: string | null | undefined) {
    const id = reviewVideoMediaIdFromUrl(url);
    if (!id) return;
    try {
      await this.reviewVideoMedia.deleteUnreferenced(id);
    } catch (error) {
      this.logger.warn(`Could not delete replaced review video ${url}: ${String(error)}`);
    }
  }

  async updateReviewVideo(id: number, dto: UpdateReviewVideoDto) {
    if (dto.videoUrl) await this.assertReadyReviewVideo(dto.videoUrl);
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

  private async assertReadyReviewVideo(url: string) {
    const id = reviewVideoMediaIdFromUrl(url);
    if (id) await this.reviewVideoMedia.playbackInfo(id);
  }
}
