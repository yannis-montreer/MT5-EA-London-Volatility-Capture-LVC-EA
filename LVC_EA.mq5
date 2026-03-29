#property strict
#property version   "1.00"
#property description "Asia session range expansion EA for MT5 using ATR-normalized breakout/retest/reversal logic"

#include <Trade/Trade.mqh>

CTrade trade;

input ENUM_TIMEFRAMES InpSignalTF = PERIOD_M5;
input double          InpLots = 0.10;
input bool            InpUseRiskPercent = false;
input double          InpRiskPercent = 1.0;
input ulong           InpMagic = 26032801;
input int             InpSlippagePoints = 30;
input bool            InpOnePositionPerSymbol = true;
input bool            InpAllowLong = true;
input bool            InpAllowShort = true;
input bool            InpCloseAtTradeWindowEnd = false;

input int             InpUtcOffsetMinutes = 0;
input int             InpAsiaStartHourUTC = 0;
input int             InpAsiaStartMinuteUTC = 0;
input int             InpAsiaEndHourUTC = 6;
input int             InpAsiaEndMinuteUTC = 0;
input int             InpTradeStartHourUTC = 7;
input int             InpTradeStartMinuteUTC = 0;
input int             InpTradeEndHourUTC = 10;
input int             InpTradeEndMinuteUTC = 0;

input int             InpATRPeriod = 14;
input ENUM_TIMEFRAMES InpATRTimeframe = PERIOD_M5;

input double          InpMinRangeATR = 0.50;
input double          InpMaxRangeATR = 2.00;

input double          InpBreakoutDistanceATR = 0.50;
input double          InpBreakoutCandleATR = 1.20;

input bool            InpEnableRetestTrade = true;
input int             InpRetestMaxBars = 5;
input double          InpRetestTouchATR = 0.20;
input double          InpRetestMaxCloseBackInATR = 0.30;
input double          InpRetestSL_ATR = 0.75;
input double          InpRetestRR = 2.00;
input double          InpRetestTP_ATR = 2.00;
input bool            InpRetestUseRangeProjectionTP = false;

input bool            InpEnableReversalTrade = true;
input int             InpReversalMaxBars = 3;
input double          InpReversalOvershootATR = 0.50;
input double          InpReversalReturnATR = 1.00;
input double          InpReversalSLBufferATR = 0.20;
input double          InpReversalRR = 2.00;
input double          InpReversalTP_ATR = 2.00;
input bool            InpReversalUseOppositeRangeTP = true;

input bool            InpUseBarCloseSignals = true;
input int             InpCooldownBarsAfterTrade = 0;

int      g_atrHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;
datetime g_sessionDayKey = 0;
int      g_lastTradeBarIndex = -1000000;
bool     g_rangeReady = false;
bool     g_dayFinished = false;
double   g_rangeHigh = 0.0;
double   g_rangeLow = 0.0;
double   g_rangeSize = 0.0;

struct SetupState
{
   bool active;
   bool bullish;
   bool breakoutSeen;
   int breakoutBarShift;
   datetime breakoutBarTime;
   double breakoutLevel;
   double breakoutExtreme;
   double breakoutATR;
   double breakoutClose;
   double breakoutHigh;
   double breakoutLow;
};

SetupState g_bullSetup;
SetupState g_bearSetup;

string DirectionText(bool bullish)
{
   return bullish ? "LONG" : "SHORT";
}

void ResetSetup(SetupState &s)
{
   s.active = false;
   s.bullish = true;
   s.breakoutSeen = false;
   s.breakoutBarShift = -1;
   s.breakoutBarTime = 0;
   s.breakoutLevel = 0.0;
   s.breakoutExtreme = 0.0;
   s.breakoutATR = 0.0;
   s.breakoutClose = 0.0;
   s.breakoutHigh = 0.0;
   s.breakoutLow = 0.0;
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, InpSignalTF, 0);
   if(t == 0)
      return false;
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

int MinutesOfDayUTC(datetime serverTime)
{
   datetime utcTime = serverTime - InpUtcOffsetMinutes * 60;
   MqlDateTime dt;
   TimeToStruct(utcTime, dt);
   return dt.hour * 60 + dt.min;
}

datetime DayKeyUTC(datetime serverTime)
{
   datetime utcTime = serverTime - InpUtcOffsetMinutes * 60;
   MqlDateTime dt;
   TimeToStruct(utcTime, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

int SessionMinutes(int hourUTC, int minuteUTC)
{
   return hourUTC * 60 + minuteUTC;
}

bool InWindowUTC(datetime serverTime, int startMin, int endMin)
{
   int nowMin = MinutesOfDayUTC(serverTime);
   if(startMin <= endMin)
      return (nowMin >= startMin && nowMin < endMin);
   return (nowMin >= startMin || nowMin < endMin);
}

bool PassedWindowUTC(datetime serverTime, int endMin)
{
   int nowMin = MinutesOfDayUTC(serverTime);
   return (nowMin >= endMin);
}

bool GetATRValue(int shift, double &atr)
{
   if(g_atrHandle == INVALID_HANDLE)
      return false;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, shift, 1, buf) < 1)
      return false;
   atr = buf[0];
   return (atr > 0.0);
}

bool SelectPosition()
{
   if(!PositionSelect(_Symbol))
      return false;
   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
      return false;
   return true;
}

bool HasOpenPosition()
{
   return SelectPosition();
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double GetTickSize()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
}

double GetTickValue()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
}

double ComputeVolumeFromRisk(double entry, double sl)
{
   if(!InpUseRiskPercent)
      return InpLots;

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double distance = MathAbs(entry - sl);
   double tickSize = GetTickSize();
   double tickValue = GetTickValue();
   if(distance <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return InpLots;

   double moneyPerLot = (distance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return InpLots;

   double vol = riskMoney / moneyPerLot;
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepVol <= 0.0)
      stepVol = 0.01;

   vol = MathMax(minVol, MathMin(maxVol, MathFloor(vol / stepVol) * stepVol));
   return vol;
}

bool EnterTrade(bool bullish, string tag, double sl, double tp)
{
   if(InpOnePositionPerSymbol && HasOpenPosition())
      return false;

   if(bullish && !InpAllowLong)
      return false;
   if(!bullish && !InpAllowShort)
      return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry = bullish ? ask : bid;

   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);
   entry = NormalizePrice(entry);

   double volume = ComputeVolumeFromRisk(entry, sl);
   if(volume <= 0.0)
      return false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);

   bool ok = false;
   string comment = StringFormat("ALRE %s %s", tag, DirectionText(bullish));

   if(bullish)
      ok = trade.Buy(volume, _Symbol, 0.0, sl, tp, comment);
   else
      ok = trade.Sell(volume, _Symbol, 0.0, sl, tp, comment);

   if(ok)
      g_lastTradeBarIndex = Bars(_Symbol, InpSignalTF);

   return ok;
}

void ResetDayState()
{
   g_rangeReady = false;
   g_dayFinished = false;
   g_rangeHigh = 0.0;
   g_rangeLow = 0.0;
   g_rangeSize = 0.0;
   ResetSetup(g_bullSetup);
   ResetSetup(g_bearSetup);
}

void BuildAsiaRange(datetime serverNow)
{
   int asiaStart = SessionMinutes(InpAsiaStartHourUTC, InpAsiaStartMinuteUTC);
   int asiaEnd = SessionMinutes(InpAsiaEndHourUTC, InpAsiaEndMinuteUTC);

   if(!PassedWindowUTC(serverNow, asiaEnd))
      return;

   datetime sessionKey = DayKeyUTC(serverNow);
   if(g_rangeReady && g_sessionDayKey == sessionKey)
      return;

   int bars = Bars(_Symbol, InpSignalTF);
   if(bars < 50)
      return;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   bool found = false;

   for(int shift = 1; shift < bars; shift++)
   {
      datetime bt = iTime(_Symbol, InpSignalTF, shift);
      if(bt == 0)
         break;
      if(DayKeyUTC(bt) != sessionKey)
         continue;

      int m = MinutesOfDayUTC(bt);
      if(InWindowUTC(bt, asiaStart, asiaEnd))
      {
         double h = iHigh(_Symbol, InpSignalTF, shift);
         double l = iLow(_Symbol, InpSignalTF, shift);
         if(h > hi) hi = h;
         if(l < lo) lo = l;
         found = true;
      }
   }

   if(!found)
      return;

   g_rangeHigh = hi;
   g_rangeLow = lo;
   g_rangeSize = hi - lo;
   g_rangeReady = true;
   g_sessionDayKey = sessionKey;

   ResetSetup(g_bullSetup);
   ResetSetup(g_bearSetup);

   g_bullSetup.active = true;
   g_bullSetup.bullish = true;
   g_bullSetup.breakoutLevel = g_rangeHigh;

   g_bearSetup.active = true;
   g_bearSetup.bullish = false;
   g_bearSetup.breakoutLevel = g_rangeLow;
}

bool RangeFiltersPass(double atr)
{
   if(!g_rangeReady || atr <= 0.0)
      return false;

   double rangeAtr = g_rangeSize / atr;
   return (rangeAtr >= InpMinRangeATR && rangeAtr <= InpMaxRangeATR);
}

void EvaluateFreshBreakout(SetupState &s, int shift, double atr)
{
   if(!s.active || s.breakoutSeen)
      return;

   double high = iHigh(_Symbol, InpSignalTF, shift);
   double low = iLow(_Symbol, InpSignalTF, shift);
   double close = iClose(_Symbol, InpSignalTF, shift);
   double open = iOpen(_Symbol, InpSignalTF, shift);
   double candleRange = high - low;

   if(s.bullish)
   {
      double distance = high - g_rangeHigh;
      if(distance >= InpBreakoutDistanceATR * atr && candleRange >= InpBreakoutCandleATR * atr && close > open)
      {
         s.breakoutSeen = true;
         s.breakoutBarShift = shift;
         s.breakoutBarTime = iTime(_Symbol, InpSignalTF, shift);
         s.breakoutExtreme = high;
         s.breakoutATR = atr;
         s.breakoutClose = close;
         s.breakoutHigh = high;
         s.breakoutLow = low;
      }
   }
   else
   {
      double distance = g_rangeLow - low;
      if(distance >= InpBreakoutDistanceATR * atr && candleRange >= InpBreakoutCandleATR * atr && close < open)
      {
         s.breakoutSeen = true;
         s.breakoutBarShift = shift;
         s.breakoutBarTime = iTime(_Symbol, InpSignalTF, shift);
         s.breakoutExtreme = low;
         s.breakoutATR = atr;
         s.breakoutClose = close;
         s.breakoutHigh = high;
         s.breakoutLow = low;
      }
   }
}

int BarsSinceBreakout(const SetupState &s)
{
   if(!s.breakoutSeen)
      return 1000000;

   datetime latestClosedBar = iTime(_Symbol, InpSignalTF, 1);
   if(latestClosedBar <= s.breakoutBarTime)
      return 0;

   int shift = iBarShift(_Symbol, InpSignalTF, s.breakoutBarTime, false);
   if(shift < 0)
      return 1000000;
   return shift - 1;
}

bool CooldownPassed()
{
   int currentBars = Bars(_Symbol, InpSignalTF);
   return ((currentBars - g_lastTradeBarIndex) > InpCooldownBarsAfterTrade);
}

bool ProcessRetest(SetupState &s, int shift, double atr)
{
   if(!InpEnableRetestTrade || !s.breakoutSeen)
      return false;

   int elapsed = BarsSinceBreakout(s);
   if(elapsed <= 0 || elapsed > InpRetestMaxBars)
      return false;

   double close = iClose(_Symbol, InpSignalTF, shift);
   double high = iHigh(_Symbol, InpSignalTF, shift);
   double low = iLow(_Symbol, InpSignalTF, shift);

   if(s.bullish)
   {
      bool touch = (low <= g_rangeHigh + InpRetestTouchATR * atr);
      bool notTooDeep = (close >= g_rangeHigh - InpRetestMaxCloseBackInATR * atr);
      bool hold = (close >= g_rangeHigh);
      if(touch && notTooDeep && hold)
      {
         double entryRef = iClose(_Symbol, InpSignalTF, shift);
         double sl = entryRef - InpRetestSL_ATR * atr;
         double tp;
         if(InpRetestUseRangeProjectionTP)
            tp = entryRef + g_rangeSize;
         else
            tp = MathMax(entryRef + InpRetestTP_ATR * atr, entryRef + (entryRef - sl) * InpRetestRR);
         ResetSetup(s);
         return EnterTrade(true, "Retest", sl, tp);
      }
   }
   else
   {
      bool touch = (high >= g_rangeLow - InpRetestTouchATR * atr);
      bool notTooDeep = (close <= g_rangeLow + InpRetestMaxCloseBackInATR * atr);
      bool hold = (close <= g_rangeLow);
      if(touch && notTooDeep && hold)
      {
         double entryRef = iClose(_Symbol, InpSignalTF, shift);
         double sl = entryRef + InpRetestSL_ATR * atr;
         double tp;
         if(InpRetestUseRangeProjectionTP)
            tp = entryRef - g_rangeSize;
         else
            tp = MathMin(entryRef - InpRetestTP_ATR * atr, entryRef - (sl - entryRef) * InpRetestRR);
         ResetSetup(s);
         return EnterTrade(false, "Retest", sl, tp);
      }
   }

   if(elapsed > InpRetestMaxBars)
      ResetSetup(s);

   return false;
}

bool ProcessReversal(SetupState &s, int shift, double atr)
{
   if(!InpEnableReversalTrade || !s.breakoutSeen)
      return false;

   int elapsed = BarsSinceBreakout(s);
   if(elapsed <= 0 || elapsed > InpReversalMaxBars)
      return false;

   double close = iClose(_Symbol, InpSignalTF, shift);
   double high = iHigh(_Symbol, InpSignalTF, shift);
   double low = iLow(_Symbol, InpSignalTF, shift);

   if(s.bullish)
   {
      double overshoot = s.breakoutExtreme - g_rangeHigh;
      double returnMove = s.breakoutExtreme - close;
      bool reentry = close < g_rangeHigh;
      bool overshootOk = overshoot >= InpReversalOvershootATR * atr;
      bool returnOk = returnMove >= InpReversalReturnATR * atr;
      if(reentry && overshootOk && returnOk)
      {
         double sl = s.breakoutExtreme + InpReversalSLBufferATR * atr;
         double entryRef = close;
         double tp = InpReversalUseOppositeRangeTP ? g_rangeLow : MathMin(entryRef - InpReversalTP_ATR * atr, entryRef - (sl - entryRef) * InpReversalRR);
         ResetSetup(s);
         return EnterTrade(false, "Reversal", sl, tp);
      }
   }
   else
   {
      double overshoot = g_rangeLow - s.breakoutExtreme;
      double returnMove = close - s.breakoutExtreme;
      bool reentry = close > g_rangeLow;
      bool overshootOk = overshoot >= InpReversalOvershootATR * atr;
      bool returnOk = returnMove >= InpReversalReturnATR * atr;
      if(reentry && overshootOk && returnOk)
      {
         double sl = s.breakoutExtreme - InpReversalSLBufferATR * atr;
         double entryRef = close;
         double tp = InpReversalUseOppositeRangeTP ? g_rangeHigh : MathMax(entryRef + InpReversalTP_ATR * atr, entryRef + (entryRef - sl) * InpReversalRR);
         ResetSetup(s);
         return EnterTrade(true, "Reversal", sl, tp);
      }
   }

   return false;
}

void ExpireOldSetups()
{
   if(g_bullSetup.breakoutSeen && BarsSinceBreakout(g_bullSetup) > MathMax(InpRetestMaxBars, InpReversalMaxBars))
      ResetSetup(g_bullSetup);
   if(g_bearSetup.breakoutSeen && BarsSinceBreakout(g_bearSetup) > MathMax(InpRetestMaxBars, InpReversalMaxBars))
      ResetSetup(g_bearSetup);
}

void ManageTradeWindowEnd(datetime serverNow)
{
   int tradeEnd = SessionMinutes(InpTradeEndHourUTC, InpTradeEndMinuteUTC);
   if(PassedWindowUTC(serverNow, tradeEnd))
   {
      g_dayFinished = true;
      ResetSetup(g_bullSetup);
      ResetSetup(g_bearSetup);

      if(InpCloseAtTradeWindowEnd && HasOpenPosition())
         trade.PositionClose(_Symbol);
   }
}

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);

   g_atrHandle = iATR(_Symbol, InpATRTimeframe, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   ResetDayState();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
}

void OnTick()
{
   if(!IsNewBar())
      return;

   datetime nowServer = TimeCurrent();
   datetime currentDayKey = DayKeyUTC(nowServer);
   if(g_sessionDayKey != 0 && currentDayKey != g_sessionDayKey)
      ResetDayState();

   BuildAsiaRange(nowServer);
   if(!g_rangeReady)
      return;

   ManageTradeWindowEnd(nowServer);
   if(g_dayFinished)
      return;

   int tradeStart = SessionMinutes(InpTradeStartHourUTC, InpTradeStartMinuteUTC);
   int tradeEnd = SessionMinutes(InpTradeEndHourUTC, InpTradeEndMinuteUTC);
   if(!InWindowUTC(nowServer, tradeStart, tradeEnd))
      return;

   if(!CooldownPassed())
      return;

   double atr = 0.0;
   if(!GetATRValue(1, atr))
      return;

   if(!RangeFiltersPass(atr))
      return;

   int shift = 1;

   if(!HasOpenPosition())
   {
      EvaluateFreshBreakout(g_bullSetup, shift, atr);
      EvaluateFreshBreakout(g_bearSetup, shift, atr);

      if(ProcessReversal(g_bullSetup, shift, atr)) return;
      if(ProcessReversal(g_bearSetup, shift, atr)) return;
      if(ProcessRetest(g_bullSetup, shift, atr)) return;
      if(ProcessRetest(g_bearSetup, shift, atr)) return;
   }

   ExpireOldSetups();
}
