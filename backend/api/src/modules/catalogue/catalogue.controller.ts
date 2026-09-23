import { Controller, Get, Head, Param, ParseIntPipe, ParseUUIDPipe, Query, Req, Res } from '@nestjs/common';
import type { Request, Response } from 'express';
import { once } from 'node:events';
import { CatalogueService } from './catalogue.service';
import { ReviewVideoMediaService } from './review-video-media.service';
import { parseVideoRange } from './review-video-range';
import { Public } from '../../common/decorators/public.decorator';
import { RequireMember } from '../../common/decorators/require-role.decorator';
import { ZodValidationPipe } from '../../common/pipes/zod-validation.pipe';
import { listProductsQuerySchema, type ListProductsQuery } from './dto';

// Deliberately no class-level @Public() (unlike this controller's own
// earlier shape): mixing one member-only route (storeBankDetails) in with
// the rest needs each public route marked individually, the same way
// member-auth.controller.ts does it — a class-level @Public() would win
// over a method's own @RequireMember() (AuthGuard's isPublic check reads
// the handler's metadata first, but only when the handler actually sets
// it; an unset handler falls through to the class's `true` regardless of
// @RequireMember(), which sets a different, RolesGuard-only key). Caught
// by catalogue.e2e-spec.ts, not by inspection.
@Controller('v1/public/catalogue')
export class CatalogueController {
  constructor(
    private readonly catalogue: CatalogueService,
    private readonly reviewVideoMedia: ReviewVideoMediaService,
  ) {}

  @Public()
  @Get('stores')
  stores() {
    return this.catalogue.listStores();
  }

  /**
   * Member-only, unlike every other route on this controller: `code` is
   * itself public (every branch's `code` is right there in `listStores`),
   * so leaving this one open too would just let a script loop it once per
   * known code and reconstruct the exact bulk bank-details dump
   * `listStores` was scoped down to stop leaking — see this endpoint's own
   * addition in `catalogue.service.ts`. Checkout already requires a signed-
   * in member before it is ever reached, so this costs the real caller
   * nothing.
   */
  @RequireMember()
  @Get('stores/:code/bank-details')
  storeBankDetails(@Param('code') code: string) {
    return this.catalogue.getStoreBankDetails(code);
  }

  @Public()
  @Get('categories')
  categories() {
    return this.catalogue.listCategories();
  }

  @Public()
  @Get('categories/:id/subcategories')
  subcategories(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.listSubcategories(id);
  }

  @Public()
  @Get('products')
  products(@Query(new ZodValidationPipe(listProductsQuerySchema)) query: ListProductsQuery) {
    return this.catalogue.listProducts(query);
  }

  @Public()
  @Get('products/:id')
  product(@Param('id', ParseIntPipe) id: number) {
    return this.catalogue.getProduct(id);
  }

  @Public()
  @Get('banners')
  banners() {
    return this.catalogue.listBanners();
  }

  @Public()
  @Get('promos')
  promos() {
    return this.catalogue.listPromos();
  }

  @Public()
  @Get('review-videos')
  async reviewVideos(@Req() request: Request) {
    const rows = await this.catalogue.listActiveReviewVideos();
    const proto = String(request.headers['x-forwarded-proto'] ?? request.protocol).split(',')[0].trim();
    const host = String(request.headers['x-forwarded-host'] ?? request.headers.host ?? '').split(',')[0].trim();
    const origin = host ? `${proto}://${host}` : '';
    return rows.map((row) => ({
      ...row,
      videoUrl: row.videoUrl.startsWith('/v1/public/') && origin ? `${origin}${row.videoUrl}` : row.videoUrl,
    }));
  }

  @Public()
  @Head('review-video-media/:id')
  async reviewVideoMediaHead(
    @Param('id', ParseUUIDPipe) id: string,
    @Res() response: Response,
  ) {
    const info = await this.reviewVideoMedia.playbackInfo(id);
    setVideoHeaders(response, info.contentType, info.byteLength);
    response.status(200).end();
  }

  @Public()
  @Get('review-video-media/:id')
  async reviewVideoMediaGet(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() request: Request,
    @Res() response: Response,
  ) {
    const info = await this.reviewVideoMedia.playbackInfo(id);
    const range = parseVideoRange(request.headers.range, info.byteLength, 2 * 1024 * 1024);
    setVideoHeaders(response, info.contentType, info.byteLength);
    if (range.kind === 'unsatisfiable') {
      response.setHeader('Content-Range', `bytes */${info.byteLength}`);
      response.setHeader('Content-Length', '0');
      response.status(416).end();
      return;
    }
    if (range.kind === 'partial') {
      const length = range.end - range.start + 1;
      const bytes = await this.reviewVideoMedia.readSlice(id, range.start, length);
      response.status(206);
      response.setHeader('Content-Range', `bytes ${range.start}-${range.end}/${info.byteLength}`);
      response.setHeader('Content-Length', length);
      response.end(bytes);
      return;
    }

    response.status(200);
    response.setHeader('Content-Length', info.byteLength);
    const sliceSize = 2 * 1024 * 1024;
    for (let start = 0; start < info.byteLength; start += sliceSize) {
      const bytes = await this.reviewVideoMedia.readSlice(id, start, Math.min(sliceSize, info.byteLength - start));
      if (!response.write(bytes)) await once(response, 'drain');
    }
    response.end();
  }

  @Public()
  @Get('membership-tiers')
  membershipTiers() {
    return this.catalogue.listMembershipTiers();
  }

  @Public()
  @Get('payment-methods')
  paymentMethods() {
    return this.catalogue.listPaymentMethods();
  }
}

function setVideoHeaders(response: Response, contentType: string, byteLength: number) {
  response.setHeader('Content-Type', contentType);
  response.setHeader('Accept-Ranges', 'bytes');
  response.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Content-Length', byteLength);
}
