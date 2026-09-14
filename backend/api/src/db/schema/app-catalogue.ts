import { bigint, boolean, date, integer, numeric, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';

/**
 * Typed READ/WRITE MIRROR of catalogue tables owned by
 * backend/db/app_schema.sql — see backend/docs/erd.md §2. Note:
 * app.shield_store has NO latitude/longitude columns in the live schema,
 * so "nearest to me" store sorting (mentioned as aspirational in
 * backend/docs/frd.md §2) is NOT implemented here — only what the schema
 * actually supports. Flagging the drift instead of quietly building
 * against wishful requirements.
 */
export const shieldStore = appSchema.table('shield_store', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  code: text('code').notNull(),
  name: text('name').notNull(),
  area: text('area').notNull(),
  city: text('city').notNull(),
  state: text('state').notNull(),
  pincode: text('pincode').notNull(),
  phone: text('phone').notNull().default(''),
  hours: text('hours').notNull().default('8:00 AM – 10:00 PM'),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const productCategory = appSchema.table('product_category', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  slug: text('slug').notNull(),
  title: text('title').notNull(),
  tabLabel: text('tab_label').notNull(),
  iconName: text('icon_name'),
  image: text('image'),
  bannerImage: text('banner_image'),
  panelTint: text('panel_tint'),
  offer: text('offer').notNull().default(''),
  sort: integer('sort').notNull().default(0),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const productSubcategory = appSchema.table('product_subcategory', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  categoryId: bigint('category_id', { mode: 'number' }).notNull(),
  label: text('label').notNull(),
  iconName: text('icon_name'),
  image: text('image'),
  offer: text('offer').notNull().default(''),
  sort: integer('sort').notNull().default(0),
});

export const product = appSchema.table('product', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  code: text('code'),
  name: text('name').notNull(),
  pack: text('pack').notNull().default(''),
  brand: text('brand'),
  categoryId: bigint('category_id', { mode: 'number' }),
  subcategoryId: bigint('subcategory_id', { mode: 'number' }),
  price: numeric('price', { precision: 12, scale: 2 }).notNull().default('0'),
  mrp: numeric('mrp', { precision: 12, scale: 2 }).notNull().default('0'),
  discountLabel: text('discount_label'),
  iconName: text('icon_name'),
  image: text('image'),
  isPrescriptionOnly: boolean('is_prescription_only').notNull().default(false),
  status: text('status').notNull().default('ACTIVE'),
  stockQuantity: numeric('stock_quantity', { precision: 12, scale: 2 }).notNull().default('0'),
  // From migration 0005_product_home_sections.sql — drives the storefront's
  // Popular/Deal/Offer-of-the-day sections. Present in the live schema; not
  // yet folded into app_schema.sql's bundled DDL (known drift, see
  // docs/decision-log.md), but real columns to mirror regardless.
  isPopular: boolean('is_popular').notNull().default(false),
  isDeal: boolean('is_deal').notNull().default(false),
  isOfferOfDay: boolean('is_offer_of_day').notNull().default(false),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const productDetail = appSchema.table('product_detail', {
  productId: bigint('product_id', { mode: 'number' }).primaryKey(),
  form: text('form'),
  manufacturer: text('manufacturer'),
  description: text('description').notNull().default(''),
  ingredients: text('ingredients').notNull().default(''),
  storage: text('storage').notNull().default(''),
  highlights: text('highlights').array().notNull().default([]),
  benefits: text('benefits').array().notNull().default([]),
  directions: text('directions').array().notNull().default([]),
  safety: text('safety').array().notNull().default([]),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const productFaq = appSchema.table('product_faq', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  productId: bigint('product_id', { mode: 'number' }).notNull(),
  question: text('question').notNull(),
  answer: text('answer').notNull(),
  sort: integer('sort').notNull().default(0),
});

export const homeBanner = appSchema.table('home_banner', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  title: text('title'),
  subtitle: text('subtitle'),
  image: text('image'),
  cta: text('cta'),
  target: text('target'),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const promo = appSchema.table('promo', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  titleTop: text('title_top'),
  titleMiddle: text('title_middle'),
  titleAccent: text('title_accent'),
  titleTail: text('title_tail'),
  cta: text('cta'),
  code: text('code'),
  percent: text('percent'),
  background: text('background'),
  startsOn: date('starts_on'),
  endsOn: date('ends_on'),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const customerReview = appSchema.table('customer_review', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  name: text('name').notNull(),
  subtitle: text('subtitle'),
  videoUrl: text('video_url'),
  durationSeconds: integer('duration_seconds'),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export const healthArticle = appSchema.table('health_article', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  slug: text('slug').notNull(),
  title: text('title').notNull(),
  topics: text('topics').array().notNull().default([]),
  author: text('author'),
  publishedOn: date('published_on'),
  heroKicker: text('hero_kicker'),
  intro: text('intro').array().notNull().default([]),
  iconName: text('icon_name'),
  tint: text('tint'),
  isPublished: boolean('is_published').notNull().default(true),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const healthArticleSection = appSchema.table('health_article_section', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  articleId: bigint('article_id', { mode: 'number' }).notNull(),
  sort: integer('sort').notNull().default(0),
  heading: text('heading').notNull(),
  paragraphs: text('paragraphs').array().notNull().default([]),
});

// Folded into backend/db/app_schema.sql from migration 0009 as part of the
// M9 client cutover — see backend/docs (erd.md §1) and the schema file's own
// comment at that table.
export const customerReviewVideo = appSchema.table('customer_review_video', {
  id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
  uuid: uuid('uuid').notNull().defaultRandom(),
  name: text('name').notNull(),
  subtitle: text('subtitle').notNull().default(''),
  videoUrl: text('video_url').notNull(),
  thumbnail: text('thumbnail'),
  isActive: boolean('is_active').notNull().default(true),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
