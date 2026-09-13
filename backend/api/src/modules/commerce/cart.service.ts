import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { cart, cartLine, product } from '../../db/schema';
import type { AddCartLineDto, UpdateCartLineDto } from './dto';

@Injectable()
export class CartService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async getOrCreateCart(memberId: number) {
    const [existing] = await this.db.select().from(cart).where(eq(cart.memberId, memberId)).limit(1);
    if (existing) return existing;
    const [created] = await this.db.insert(cart).values({ memberId }).returning();
    return created;
  }

  async getCart(memberId: number) {
    const theCart = await this.getOrCreateCart(memberId);
    const lines = await this.db.select().from(cartLine).where(eq(cartLine.cartId, theCart.id));
    return { ...theCart, lines };
  }

  async addLine(memberId: number, dto: AddCartLineDto) {
    const theCart = await this.getOrCreateCart(memberId);

    // Price/name/mrp/image always come from the live product row, never
    // from the client, so a stale or tampered client-submitted price can
    // never reach checkout. Deliberately NOT read through
    // CatalogueService's cache — cart/checkout pricing must be live, not
    // up-to-5-minutes stale (see backend/docs/trd.md cache TTLs).
    const [liveProduct] = await this.db.select().from(product).where(eq(product.id, dto.productId)).limit(1);
    if (!liveProduct || liveProduct.status !== 'ACTIVE') {
      throw new NotFoundException({ error: { code: 'NOT_FOUND', message: 'Product not available' } });
    }

    const [line] = await this.db
      .insert(cartLine)
      .values({
        cartId: theCart.id,
        productId: liveProduct.id,
        name: liveProduct.name,
        pack: liveProduct.pack,
        price: liveProduct.price,
        mrp: liveProduct.mrp,
        image: liveProduct.image,
        qty: dto.qty,
      })
      .returning();
    return line;
  }

  async updateLineQty(memberId: number, lineId: number, dto: UpdateCartLineDto) {
    await this.assertOwnsLine(memberId, lineId);
    const [updated] = await this.db.update(cartLine).set({ qty: dto.qty }).where(eq(cartLine.id, lineId)).returning();
    return updated;
  }

  async removeLine(memberId: number, lineId: number) {
    await this.assertOwnsLine(memberId, lineId);
    await this.db.delete(cartLine).where(eq(cartLine.id, lineId));
  }

  private async assertOwnsLine(memberId: number, lineId: number) {
    const theCart = await this.getOrCreateCart(memberId);
    const [line] = await this.db
      .select({ id: cartLine.id })
      .from(cartLine)
      .where(and(eq(cartLine.id, lineId), eq(cartLine.cartId, theCart.id)))
      .limit(1);
    if (!line) {
      throw new ForbiddenException({ error: { code: 'FORBIDDEN', message: 'Cart line does not belong to this member' } });
    }
  }
}
