import { sendResponse } from '../../../../utils/response.js';
import {
    getPayLaterAccount,
    repayFromWallet,
    startRazorpayRepayment,
    verifyRazorpayRepayment,
} from '../services/payLater.service.js';

export const getPayLaterAccountController = async (req, res, next) => {
    try {
        const account = await getPayLaterAccount(req.user?.userId);
        return sendResponse(res, 200, 'Pay Later account fetched successfully', { payLater: account });
    } catch (error) {
        next(error);
    }
};

export const repayFromWalletController = async (req, res, next) => {
    try {
        const data = await repayFromWallet(req.user?.userId);
        return sendResponse(res, 200, 'Pay Later due cleared from wallet', data);
    } catch (error) {
        next(error);
    }
};

export const startRazorpayRepaymentController = async (req, res, next) => {
    try {
        const data = await startRazorpayRepayment(req.user?.userId);
        return sendResponse(res, 200, 'Repayment order created successfully', data);
    } catch (error) {
        next(error);
    }
};

export const verifyRazorpayRepaymentController = async (req, res, next) => {
    try {
        const data = await verifyRazorpayRepayment(req.user?.userId, req.body || {});
        return sendResponse(res, 200, 'Pay Later due cleared', data);
    } catch (error) {
        next(error);
    }
};
