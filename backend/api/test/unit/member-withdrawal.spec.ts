import { isUntouchedByStore } from '../../src/modules/commerce/member-withdrawal';

const fresh = {
  status: 'PROCESSING',
  paymentStatus: 'PENDING',
  reviewedAt: null,
  storeContactedAt: null,
  convertedToBillAt: null,
};

describe('isUntouchedByStore', () => {
  it('lets a member pull back an order the store has not touched', () => {
    expect(isUntouchedByStore(fresh, false)).toBe(true);
  });

  it.each([
    ['reviewed', { reviewedAt: new Date() }],
    ['contacted', { storeContactedAt: new Date() }],
    ['converted to a bill', { convertedToBillAt: new Date() }],
    ['paid', { paymentStatus: 'PAID' }],
    ['out for delivery', { status: 'OUT_FOR_DELIVERY' }],
    ['delivered', { status: 'DELIVERED' }],
  ])('locks it once the store has %s it', (_label, change) => {
    expect(isUntouchedByStore({ ...fresh, ...change }, false)).toBe(false);
  });

  it('locks it once a bill has been sent', () => {
    expect(isUntouchedByStore(fresh, true)).toBe(false);
  });
});
