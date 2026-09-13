import { Inject, Injectable } from '@nestjs/common';
import { count, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { adminUser, agentRequest, order, prescription, users, walletCard } from '../../db/schema';
import { CacheService } from '../../cache/cache.service';

const TTL = 60; // short — these are operational counts staff check often, but a live join per refresh doesn't scale (see backend/docs/trd.md)

/** Pre-aggregated, cache-backed — never a live cross-table join per dashboard load. */
@Injectable()
export class DashboardService {
  constructor(
    @Inject(DRIZZLE) private readonly db: Database,
    private readonly cache: CacheService,
  ) {}

  async getSummary() {
    return this.cache.getOrSet('dashboard:summary', TTL, async () => {
      const [pendingAgentRequests] = await this.db.select({ n: count() }).from(agentRequest).where(eq(agentRequest.status, 'PENDING'));
      const [pendingWalletCards] = await this.db.select({ n: count() }).from(walletCard).where(eq(walletCard.status, 'PENDING'));
      const [pendingPrescriptions] = await this.db
        .select({ n: count() })
        .from(prescription)
        .where(eq(prescription.status, 'AWAITING_REVIEW'));
      const [processingOrders] = await this.db.select({ n: count() }).from(order).where(eq(order.status, 'PROCESSING'));
      const [totalMembers] = await this.db.select({ n: count() }).from(users);
      const [totalStaff] = await this.db.select({ n: count() }).from(adminUser);

      return {
        pendingAgentRequests: pendingAgentRequests.n,
        pendingWalletCards: pendingWalletCards.n,
        pendingPrescriptions: pendingPrescriptions.n,
        processingOrders: processingOrders.n,
        totalMembers: totalMembers.n,
        totalStaff: totalStaff.n,
      };
    });
  }
}
