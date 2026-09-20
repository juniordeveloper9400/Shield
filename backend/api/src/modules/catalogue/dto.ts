import { z } from 'zod';

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

export const updateCategorySchema = createCategorySchema.partial();

export const createProductSchema = z.object({
  code: z.string().optional(),
  name: z.string().min(1),
  pack: z.string().default(''),
  brand: z.string().optional(),
  categoryId: z.number().int().positive().optional(),
  subcategoryId: z.number().int().positive().optional(),
  price: z.number().nonnegative(),
  mrp: z.number().nonnegative(),
  discountLabel: z.string().optional(),
  iconName: z.string().optional(),
  image: z.string().optional(),
  isPrescriptionOnly: z.boolean().default(false),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
  stockQuantity: z.number().nonnegative().default(0),
});

export const updateProductSchema = createProductSchema.partial();

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

export const createReviewVideoUploadSchema = z.object({
  contentType: z.enum(REVIEW_VIDEO_CONTENT_TYPES),
  /** Exact file size in bytes — signed into the upload URL, so it can't be exceeded. */
  size: z.number().int().positive().max(MAX_REVIEW_VIDEO_BYTES),
});

export const deleteReviewVideoMediaSchema = z.object({ url: z.string().min(1) });

export type ListProductsQuery = z.infer<typeof listProductsQuerySchema>;
export type CreateCategoryDto = z.infer<typeof createCategorySchema>;
export type UpdateCategoryDto = z.infer<typeof updateCategorySchema>;
export type CreateProductDto = z.infer<typeof createProductSchema>;
export type UpdateProductDto = z.infer<typeof updateProductSchema>;
export type CreateReviewVideoDto = z.infer<typeof createReviewVideoSchema>;
export type UpdateReviewVideoDto = z.infer<typeof updateReviewVideoSchema>;
export type CreateReviewVideoUploadDto = z.infer<typeof createReviewVideoUploadSchema>;
export type DeleteReviewVideoMediaDto = z.infer<typeof deleteReviewVideoMediaSchema>;
