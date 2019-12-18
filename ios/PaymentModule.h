#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <StoreKit/StoreKit.h>

@interface McPaymentModule : RCTEventEmitter <RCTBridgeModule, SKProductsRequestDelegate,SKPaymentTransactionObserver>
{
  SKProductsRequest *productsRequest;
  NSMutableArray *validProducts;
}

@end
