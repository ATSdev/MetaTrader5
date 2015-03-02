#include <Indicators\Trend.mqh>
#include <Trade\SymbolInfo.mqh>

#property copyright "ATSdev"
#property link      "http://www.meetup.com/Toronto-Automated-Trading-Strategies-Deve"
#property version   "1.00"
#property strict

input int      BBPeriod    = 20;
input int      BBStdDev    = 2;
input int      StopLoss    = 50;
input int      TakeProfit  = 250;
input float    Lot         = 0.1;
input bool     PrintDebug  = true;
input bool     PrintOrders = false;

      int      stopLossAdj = 10;

CiBands bband;

int OnInit() {
   stopLossAdj = StopLoss;
   // avoiding "Minimum StopLoss = 10 points"
   //double stopLossMin = MarketInfo(Symbol(), MODE_STOPLEVEL);
   //if (stopLoss < stopLossMin) {
   //   printf("RESETTING_STOP_LOSS_TO_MINIMAL_ACCEPTED stopLoss[%f] => stopLossMin[%f]", StopLoss, stopLossMin);
   //   stopLoss = stopLossMin;
   //}
   bband.Create(_Symbol,PERIOD_CURRENT,BBPeriod,0,BBStdDev,0);
   
   return(INIT_SUCCEEDED);
}

void OnTick() {
   MqlTick tick;
   if (SymbolInfoTick(Symbol(),tick) == false) {
      Print("SymbolInfoTick() failed, error = ", GetLastError());
      return;
   }
   //Print(last_tick.time,": Bid = ",last_tick.bid, " Ask = ",last_tick.ask,"  Volume = ",last_tick.volume);

   int barSerno = Bars(_Symbol,_Period);
	int barToWait = BBPeriod - barSerno;
	if (barToWait > 0) {
	   Print("barToWait=",barToWait);
	   return;
	}
	if(PositionSelect(_Symbol)) {
	   return;
	}

   bband.Refresh();
   double bbValueUpper = bband.GetData(1,barSerno);
   double bbValueLower = bband.GetData(2,barSerno);
   
   // 1.567478987566 => 1.56748 if our broker provides 5 digits after the decimal point
   bbValueUpper   = NormalizeDouble(bbValueUpper,Digits());
   bbValueLower   = NormalizeDouble(bbValueLower,Digits());

  
   bool signal_buy   = tick.bid < bbValueLower;
   bool signal_sell  = tick.ask > bbValueUpper;
   bool signal_error = signal_buy && signal_sell;

   string signal_buy_str = "";
   if (signal_buy)   signal_buy_str = "BUY";
   
   string signal_sell_str = "";
   if (signal_sell)  signal_sell_str = "SELL";
   
   if (PrintDebug || signal_error) {
      printf("[%s] [%f]...[%f] %s %s", TimeToString(tick.time,TIME_SECONDS)
         , bbValueLower, bbValueUpper, signal_buy_str, signal_sell_str);
   }
   
   if (signal_error) {
      Print("I_REFUSE_TO_PROCESS_BOTH signal_buy && signal_sell");
      return;
   }
   
   if (signal_buy)   buy(tick);
   if (signal_sell)  sell(tick);
}


// taken from MQL4 Reference / Trade Functions / OrderSend 
void buy(MqlTick& tick) {
   double price=tick.ask;
   //--- calculated SL and TP prices must be normalized
   double stoploss   =NormalizeDouble(tick.bid-stopLossAdj*_Point,Digits());
   double takeprofit =NormalizeDouble(tick.bid+TakeProfit*_Point,Digits());
   //--- place market order to buy 1 lot
   string orderComment = "buy@" + price + " TP:" + takeprofit + " SL" + stoploss;
   if (PrintOrders) Print(orderComment);
   //MQL4 int ticket=OrderSend(Symbol(),OP_BUY,Lot,price,3,stoploss,takeprofit,orderComment,16384,0,clrGreen);
   //MQL5
   MqlTradeRequest request={0};
   request.action=TRADE_ACTION_DEAL;            // setting a pending order
   request.magic=16384;                         // ORDER_MAGIC
   request.symbol=_Symbol;                      // symbol
   request.volume=Lot;                          // volume in 0.1 lots
   request.sl=stoploss;
   request.tp=takeprofit;
   request.type=ORDER_TYPE_BUY;                 // order type
   request.price=price;                         // open price
   request.comment = orderComment;
   MqlTradeResult result={0};
   OrderSend(request,result);
   Print(__FUNCTION__,":",result.comment);
   if(result.retcode==10016) Print(result.bid,result.ask,result.price);
   int ticket = result.deal;
   
   if(ticket<0) {
      int err = GetLastError();
      printf("buy() OrderSend failed with error #%d", err);
   } else {
      Print("buy() OrderSend placed successfully");
   }
}

// buy() inversed
void sell(MqlTick& tick) {
   double price=tick.bid;
   //--- calculated SL and TP prices must be normalized
   double stoploss   =NormalizeDouble(tick.ask+stopLossAdj*_Point,Digits());
   double takeprofit =NormalizeDouble(tick.ask-TakeProfit*_Point,Digits());
   //--- place market order to buy 1 lot
   string orderComment = "sell@" + price + " TP:" + takeprofit + " SL" + stoploss;
   if (PrintOrders) Print(orderComment);
   //MQL4 int ticket=OrderSend(Symbol(),OP_SELL,Lot,price,3,stoploss,takeprofit,orderComment,16384,0,clrOrangeRed);
   //MQL5
   MqlTradeRequest request={0};
   request.action=TRADE_ACTION_DEAL;            // setting a pending order
   request.magic=16384;                         // ORDER_MAGIC
   request.symbol=_Symbol;                      // symbol
   request.volume=Lot;                          // volume in 0.1 lots
   request.sl=stoploss;
   request.tp=takeprofit;
   request.type=ORDER_TYPE_SELL;                // order type
   request.price=price;                         // open price
   request.comment = orderComment;
   MqlTradeResult result={0};
   OrderSend(request,result);
   Print(__FUNCTION__,":",result.comment);
   if(result.retcode==10016) Print(result.bid,result.ask,result.price);
   int ticket = result.deal;
   
   if(ticket<0) {
      int err = GetLastError();
      printf("sell() OrderSend failed with error #%d");
   } else {
      Print("sell() OrderSend placed successfully");
   }
}
