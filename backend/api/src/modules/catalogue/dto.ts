import { z } from 'zod';

export const setAdminWhatsappSchema = z.object({ value: z.string().trim().default('') });
export type SetAdminWhatsappDto = z.infer<typeof setAdminWhatsappSchema>;

export const listProductsQuerySchema = z.object({
  categoryId: z.coerce.number().int().positive().optional(),
  subcategoryId: z.coerce.number().int().positive().optional(),
  cursor: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const createCategorySchema = z.object({
  slug: z.string().min(1),
  title: z.string().min(1),
  tabLabel: z.string().min(1),
  iconName: z.string().optional(),
  image: z.string().optional(),
  bannerImage: z.string().optional(),
  panelTint: z.string().optional(),
  offer: z.string().default(''),
  sort: z.number().int().default(0),
  isActive: z.boolean().default(true),
});

// Slug is immutable once created (shieldweb's own UPDATE never touches it
// either) — omitted here rather than merely optional, so a caller can't
// change it by mistake.
export const updateCategorySchema = createCategorySchema.omit({ slug: true }).partial();

export const setCategoryActiveSchema = z.object({ isActive: z.boolean() });
export const setCategorySortSchema = z.object({ sort: z.number().int() });

export const createSubcategorySchema = z.object({
  label: z.string().min(1),
  iconName: z.string().default(''),
  image: z.string().default(''),
  offer: z.string().default(''),
  sort: z.number().int().default(0),
});

export const updateSubcategorySchema = createSubcategorySchema;

export const createBannerSchema = z.object({
  // Free text, matching app.home_banner.placement itself (migration 0069's
  // own doc: "'home' ... unless the caller asks for another, e.g. 'lab'"
  // — an open set, not a fixed enum at the DB level).
  placement: z.string().min(1).default('home'),
  title: z.string().default(''),
  subtitle: z.string().default(''),
  image: z.string().default(''),
  cta: z.string().default(''),
  target: z.string().default(''),
  isActive: z.boolean().default(true),
  /** Appended after the placement's current last banner when omitted. */
  sort: z.number().int().optional(),
});

export const updateBannerSchema = z.object({
  title: z.string(),
  subtitle: z.string(),
  image: z.string(),
  cta: z.string(),
  target: z.string(),
  isActive: z.boolean(),
  sort: z.number().int(),
});

export const setBannerSortSchema = z.object({ sort: z.number().int() });
export const setBannerActiveSchema = z.object({ isActive: z.boolean() });

const productFaqInputSchema = z.object({
  question: z.string().default(''),
  answer: z.string().default(''),
});

/** Matches shieldweb's `ProductDetailInput` field for field — the list
 *  fields are one newline-separated textarea each on the console side,
 *  split into `text[]` server-side (see CatalogueService.writeProductDetail). */
const productDetailInputSchema = z.object({
  form: z.string().default(''),
  manufacturer: z.string().default(''),
  description: z.string().default(''),
  ingredients: z.string().default(''),
  storage: z.string().default(''),
  highlights: z.string().default(''),
  benefits: z.string().default(''),
  directions: z.string().default(''),
  safety: z.string().default(''),
  faqs: z.array(productFaqInputSchema).default([]),
});

const blankDetail = {
  form: '',
  manufacturer: '',
  description: '',
  ingredients: '',
  storage: '',
  highlights: '',
  benefits: '',
  directions: '',
  safety: '',
  faqs: [] as { question: string; answer: string }[],
};

/**
 * Matches shieldweb's `NewProduct` shape field for field (console console
 * picks a category by slug, not id — resolved server-side, see
 * CatalogueService.resolveCategoryId). `subcategoryId` is `''` for
 * "unfiled", same convention `app.product_subcategory` itself uses.
 * No `discountLabel` input: the discount shown to members is always derived
 * from `price`/`mrp` server-side (see CatalogueService.discountLabelFor), so
 * it can never drift from the real price.
 */
export const createProductSchema = z.object({
  code: z.string().trim().default(''),
  name: z.string().trim().min(1),
  pack: z.string().trim().default(''),
  brand: z.string().trim().default(''),
  categorySlug: z.string().trim().min(1),
  subcategoryId: z.string().trim().default(''),
  price: z.number().nonnegative(),
  mrp: z.number().nonnegative(),
  isPrescriptionOnly: z.boolean().default(false),
  stockQuantity: z.number().nonnegative().default(0),
  status: z.enum(['active', 'inactive']).default('active'),
  /** A resized JPEG data URI, or '' for no image. */
  image: z.string().default(''),
  /** Extra gallery images beyond the primary, written to `app.product_image`. */
  extraImages: z.array(z.string()).default([]),
  isPopular: z.boolean().default(false),
  isDeal: z.boolean().default(false),
  isOfferOfDay: z.boolean().default(false),
  detail: productDetailInputSchema.default(blankDetail),
});

export const updateProductSchema = createProductSchema.partial();

export const setProductStatusSchema = z.object({ status: z.enum(['active', 'inactive']) });

/** An "until" is only meaningful while its own flag is true — see
 *  CatalogueService.updateProductSections, which clears it the moment the
 *  flag goes false rather than trusting the caller to. `null` means "set,
 *  no expiry"; omitted leaves whatever expiry is already on record alone. */
export const updateProductSectionsSchema = z.object({
  isPopular: z.boolean(),
  isDeal: z.boolean(),
  isOfferOfDay: z.boolean(),
  popularUntil: z.string().datetime().nullable().optional(),
  dealUntil: z.string().datetime().nullable().optional(),
  offerOfDayUntil: z.string().datetime().nullable().optional(),
});

export const createBrandSchema = z.object({ name: z.string().trim().min(1) });
export const renameBrandSchema = z.object({ name: z.string().trim().min(1) });

/** Shared by createStoreSchema/updateStoreSchema — matches shieldweb's
 *  `Store`/`NewStore` shape (shieldweb/src/types/index.ts) field for field,
 *  so the console needs no payload reshaping when it switches from raw SQL
 *  to this endpoint. */
const storeFields = {
  code: z.string().trim().min(1).toUpperCase(),
  name: z.string().trim().min(1),
  area: z.string().trim().min(1),
  city: z.string().trim().min(1),
  state: z.string().trim().min(1),
  pincode: z.string().trim().min(1),
  phone: z.string().trim().default(''),
  hours: z.string().trim().default('8:00 AM – 10:00 PM'),
  isActive: z.boolean().default(true),
  /** Standalone pharmacy, standalone lab, or both — the server always
   *  derives `offersLabCollection` from this (see CatalogueService), so a
   *  client-sent value for it is accepted for backward compatibility but
   *  never trusted. */
  storeType: z.enum(['PHARMACY', 'LAB', 'PHARMACY_LAB']).default('PHARMACY_LAB'),
  offersLabCollection: z.boolean().default(true),
  latitude: z.number().min(-90).max(90).nullable().default(null),
  longitude: z.number().min(-180).max(180).nullable().default(null),
  mapsUrl: z.string().trim().default(''),
  bankAccountName: z.string().trim().default(''),
  bankAccountNumber: z.string().trim().default(''),
  bankIfsc: z.string().trim().toUpperCase().default(''),
  bankName: z.string().trim().default(''),
};

export const createStoreSchema = z.object(storeFields);
export const updateStoreSchema = z.object(storeFields).partial();
export const setStoreActiveSchema = z.object({ isActive: z.boolean() });
export const setStoreOffersLabSchema = z.object({ offersLabCollection: z.boolean() });

export const createReviewVideoSchema = z.object({
  name: z.string().min(1),
  subtitle: z.string().default(''),
  videoUrl: z.string().min(1),
  thumbnail: z.string().optional(),
  isActive: z.boolean().default(true),
  sort: z.number().int().optional(),
});

export const updateReviewVideoSchema = createReviewVideoSchema.partial();

/** What the console may upload as a customer review clip. */
export const REVIEW_VIDEO_CONTENT_TYPES = ['video/mp4', 'video/webm', 'video/quicktime'] as const;
export const MAX_REVIEW_VIDEO_BYTES = 200 * 1024 * 1024;

export const createReviewVideoMediaSchema = z.object({
  contentType: z.enum(REVIEW_VIDEO_CONTENT_TYPES),
  byteLength: z.number().int().positive().max(MAX_REVIEW_VIDEO_BYTES),
  sha256: z.string().regex(/^[a-f0-9]{64}$/),
});

export const reviewVideoChunkSchema = z.object({ data: z.string().min(1) });

export type CreateStoreDto = z.infer<typeof createStoreSchema>;
export type UpdateStoreDto = z.infer<typeof updateStoreSchema>;
export type SetStoreActiveDto = z.infer<typeof setStoreActiveSchema>;
export type SetStoreOffersLabDto = z.infer<typeof setStoreOffersLabSchema>;
export type ListProductsQuery = z.infer<typeof listProductsQuerySchema>;
export type CreateCategoryDto = z.infer<typeof createCategorySchema>;
export type UpdateCategoryDto = z.infer<typeof updateCategorySchema>;
export type CreateProductDto = z.infer<typeof createProductSchema>;
export type UpdateProductDto = z.infer<typeof updateProductSchema>;
export type SetProductStatusDto = z.infer<typeof setProductStatusSchema>;
export type UpdateProductSectionsDto = z.infer<typeof updateProductSectionsSchema>;
export type CreateBrandDto = z.infer<typeof createBrandSchema>;
export type RenameBrandDto = z.infer<typeof renameBrandSchema>;
export type CreateReviewVideoDto = z.infer<typeof createReviewVideoSchema>;
export type UpdateReviewVideoDto = z.infer<typeof updateReviewVideoSchema>;
export type CreateReviewVideoMediaDto = z.infer<typeof createReviewVideoMediaSchema>;
export type ReviewVideoChunkDto = z.infer<typeof reviewVideoChunkSchema>;
export type CreateBannerDto = z.infer<typeof createBannerSchema>;
export type UpdateBannerDto = z.infer<typeof updateBannerSchema>;
export type SetBannerSortDto = z.infer<typeof setBannerSortSchema>;
export type SetBannerActiveDto = z.infer<typeof setBannerActiveSchema>;
export type SetCategoryActiveDto = z.infer<typeof setCategoryActiveSchema>;
export type SetCategorySortDto = z.infer<typeof setCategorySortSchema>;
export type CreateSubcategoryDto = z.infer<typeof createSubcategorySchema>;
export type UpdateSubcategoryDto = z.infer<typeof updateSubcategorySchema>;
