import mongoose from 'mongoose';
import { ValidationError } from '../../../../core/auth/errors.js';
import { FoodUser } from '../../../../core/users/user.model.js';
import { FoodOrder } from '../../orders/models/order.model.js';
import * as userWalletService from './userWallet.service.js';
import {
    createRazorpayOrder,
    getRazorpayKeyId,
    isRazorpayConfigured,
    verifyPaymentSignature,
    fetchRazorpayPayment,
} from '../../orders/helpers/razorpay.helper.js';

const ELIGIBLE_DELIVERED_ORDERS = 3;

const loadUser = async (userId) => {
    const id = String(userId || '');
    if (!id || !mongoose.Types.ObjectId.isValid(id)) {
        throw new ValidationError('User not found');
    }
    const user = await FoodUser.findById(id);
    if (!user) throw new ValidationError('User not found');
    return user;
};

/**
 * Eligibility is earned once and cached on the user (payLater.eligible)
 * rather than recomputed on every request. A user qualifies after 3+
 * delivered orders with no order currently sitting in a cancelled/failed
 * COD state — cheap enough to check with two counts, no new denormalized
 * counters needed on the order model.
 */
async function refreshEligibility(user) {
    if (user.payLater?.eligible) return user;

    const [deliveredCount, badCodCount] = await Promise.all([
        FoodOrder.countDocuments({ userId: user._id, orderStatus: 'delivered' }),
        FoodOrder.countDocuments({
            userId: user._id,
            'payment.method': 'cash',
            orderStatus: { $in: ['cancelled_by_restaurant', 'cancelled_by_admin'] },
        }),
    ]);

    if (deliveredCount >= ELIGIBLE_DELIVERED_ORDERS && badCodCount === 0) {
        user.payLater.eligible = true;
        await user.save();
    }
    return user;
}

/** Shape returned to the app: eligibility, limit, current due, and how much room is left. */
export async function getPayLaterAccount(userId) {
    let user = await loadUser(userId);
    user = await refreshEligibility(user);
    const limit = Number(user.payLater?.limit || 0);
    const amountDue = Number(user.payLater?.amountDue || 0);
    return {
        eligible: !!user.payLater?.eligible,
        limit,
        amountDue,
        availableCredit: Math.max(0, limit - amountDue),
    };
}

/**
 * The "must clear dues before next order" rule applies to every payment
 * method, not just Pay Later itself — so order.service.js calls this before
 * creating ANY order, regardless of which method the user picked.
 */
export async function assertNoOutstandingDue(userId) {
    const user = await loadUser(userId);
    const amountDue = Number(user.payLater?.amountDue || 0);
    if (amountDue > 0) {
        throw new ValidationError(
            `Please clear your Pay Later due of ₹${amountDue.toFixed(2)} before placing a new order.`,
        );
    }
}

/**
 * Extends credit for a new order. Called from order.service.js right after
 * the order saves successfully — mirrors how wallet deduction happens post-save.
 * Throws (and the caller deletes the just-created order, same as the wallet
 * insufficient-balance path) if the user isn't eligible or the order exceeds
 * their limit.
 */
export async function chargePayLater(userId, orderAmount) {
    const amount = Number(orderAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
        throw new ValidationError('Invalid order amount');
    }

    const user = await refreshEligibility(await loadUser(userId));
    if (!user.payLater?.eligible) {
        throw new ValidationError('You are not yet eligible for Pay Later.');
    }
    const limit = Number(user.payLater.limit || 0);
    const currentDue = Number(user.payLater.amountDue || 0);
    if (currentDue + amount > limit) {
        throw new ValidationError(
            `This order (₹${amount.toFixed(2)}) exceeds your remaining Pay Later credit of ₹${(limit - currentDue).toFixed(2)}.`,
        );
    }

    user.payLater.amountDue = currentDue + amount;
    await user.save();
}

/**
 * Cancellation counterpart to chargePayLater — nothing was ever collected
 * upfront (same as the 'cash' branch in applyCancellationRefund), so
 * "refunding" a Pay Later order just waives the due back down.
 */
export async function waivePayLaterDue(userId, orderAmount) {
    const amount = Number(orderAmount);
    if (!Number.isFinite(amount) || amount <= 0) return;

    const user = await loadUser(userId);
    user.payLater.amountDue = Math.max(0, Number(user.payLater.amountDue || 0) - amount);
    await user.save();
}

/** Pay off the full outstanding due from the Fudron Wallet balance. */
export async function repayFromWallet(userId) {
    const user = await loadUser(userId);
    const amountDue = Number(user.payLater?.amountDue || 0);
    if (amountDue <= 0) {
        throw new ValidationError('No Pay Later due to clear');
    }

    await userWalletService.deductWalletBalance(userId, amountDue, 'Pay Later repayment');
    user.payLater.amountDue = 0;
    await user.save();
    return { amountRepaid: amountDue };
}

/** Step 1 of online repayment: open a Razorpay order for the current due. */
export async function startRazorpayRepayment(userId) {
    const user = await loadUser(userId);
    const amountDue = Number(user.payLater?.amountDue || 0);
    if (amountDue <= 0) {
        throw new ValidationError('No Pay Later due to clear');
    }
    if (!isRazorpayConfigured()) {
        throw new ValidationError('Online payment is not available right now');
    }

    const amountPaise = Math.round(amountDue * 100);
    const rzOrder = await createRazorpayOrder(amountPaise, 'INR', `paylater_${user._id}`);
    return {
        key: getRazorpayKeyId(),
        orderId: rzOrder.id,
        amount: rzOrder.amount,
        currency: rzOrder.currency || 'INR',
        amountDue,
    };
}

/** Step 2 of online repayment: verify the Razorpay signature, then zero the due. */
export async function verifyRazorpayRepayment(userId, { razorpayOrderId, razorpayPaymentId, razorpaySignature }) {
    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        throw new ValidationError('Missing payment verification details');
    }
    const valid = verifyPaymentSignature(razorpayOrderId, razorpayPaymentId, razorpaySignature);
    if (!valid) {
        throw new ValidationError('Payment verification failed');
    }

    const payment = await fetchRazorpayPayment(razorpayPaymentId);
    if (!payment || payment.status !== 'captured') {
        throw new ValidationError('Payment was not captured');
    }

    const user = await loadUser(userId);
    user.payLater.amountDue = 0;
    await user.save();
    return { amountRepaid: Number(payment.amount) / 100 };
}
