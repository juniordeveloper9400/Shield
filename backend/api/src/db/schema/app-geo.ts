import { bigint, integer, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { appSchema } from './app-identity';
import { agent } from './app-agent';

/**
 * Typed READ-ONLY mirror of the geo hierarchy from migration
 * backend/db/migrations/0014_geo_hierarchy.sql — NOT yet folded into
 * backend/db/app_schema.sql, see backend/docs/erd.md §1 "resolve existing
 * drift first". This service only ever reads these tables (seeded
 * separately via backend/db/seed_kerala_geo.dart), so no insert-default
 * concerns apply — ids are real Postgres `uuidv7()` values already there.
 */
export const lsgdTypeEnum = appSchema.enum('lsgd_type', ['corporation', 'municipality', 'grama_panchayat']);

export const region = appSchema.table('region', {
  id: uuid('id').primaryKey(),
  nationalAgentId: bigint('national_agent_id', { mode: 'number' }).references(() => agent.id),
  name: text('name').notNull(),
  code: text('code').notNull().default(''),
  sort: integer('sort').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export const state = appSchema.table('state', {
  id: uuid('id').primaryKey(),
  regionId: uuid('region_id').notNull(),
  name: text('name').notNull(),
  code: text('code').notNull().default(''),
  sort: integer('sort').notNull().default(0),
});

export const district = appSchema.table('district', {
  id: uuid('id').primaryKey(),
  stateId: uuid('state_id').notNull(),
  name: text('name').notNull(),
  code: text('code').notNull().default(''),
  sort: integer('sort').notNull().default(0),
});

export const assembly = appSchema.table('assembly', {
  id: uuid('id').primaryKey(),
  districtId: uuid('district_id').notNull(),
  name: text('name').notNull(),
  code: text('code').notNull().default(''),
  sort: integer('sort').notNull().default(0),
});

export const lsgd = appSchema.table('lsgd', {
  id: uuid('id').primaryKey(),
  assemblyId: uuid('assembly_id'),
  type: lsgdTypeEnum('type').notNull(),
  name: text('name').notNull(),
  code: text('code').notNull().default(''),
  sort: integer('sort').notNull().default(0),
});

export const ward = appSchema.table('ward', {
  id: uuid('id').primaryKey(),
  lsgdId: uuid('lsgd_id').notNull(),
  wardNumber: integer('ward_number').notNull(),
  name: text('name').notNull().default(''),
  code: text('code').notNull().default(''),
  sort: integer('sort').notNull().default(0),
});
