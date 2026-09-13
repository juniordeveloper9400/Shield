import { Inject, Injectable } from '@nestjs/common';
import { desc, eq } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';
import { referral } from '../../db/schema';
import type { CreateReferralDto } from './dto';

@Injectable()
export class ReferralService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async create(memberId: number, dto: CreateReferralDto) {
    const [created] = await this.db
      .insert(referral)
      .values({ inviterMemberId: memberId, inviteePhone: dto.inviteePhone })
      .returning();
    return created;
  }

  async listForMember(memberId: number) {
    return this.db.select().from(referral).where(eq(referral.inviterMemberId, memberId)).orderBy(desc(referral.createdAt));
  }
}
