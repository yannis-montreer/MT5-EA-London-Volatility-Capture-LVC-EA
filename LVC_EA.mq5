#property strict
#property version   "1.10"
#property description "Asia session range expansion EA for MT5 with ATR + time-based breakout freshness"

#include <Trade/Trade.mqh>

CTrade trade;

input ENUM_TIMEFRAMES InpSignalTF = PERIOD_M5;
input double          InpLots = 0.10;
input bool            InpUseRiskPercent = false;
input double          InpRiskPercent = 1.0;
input ulong           InpMagic = 26032801;
input int             InpSlippagePoints = 30;
input bool            InpOnePositionPerSymbol = true;

// 🔹 NEW: Breakout freshness constraint
input int             InpMaxBreakoutBarsFromWindowStart = 9;

input int             InpUtcOffsetMinutes = 0;
input int             InpAsiaStartHourUTC = 0;
input int             InpAsiaEndHourUTC = 6;
input int             InpTradeStartHourUTC = 7;
input int             InpTradeEndHourUTC = 10;

input int             InpATRPeriod = 14;

input double          InpBreakoutDistanceATR = 0.5;
input double          InpBreakoutCandleATR = 1.2;

int      g_atrHandle;
datetime g_lastBarTime = 0;
int      g_tradeWindowStartBar = -1;
bool     g_windowInitialized = false;

double   g_rangeHigh = 0;
double   g_rangeLow = 0;
bool     g_rangeReady = false;

bool IsNewBar()
{
   datetime t = iTime(_Symbol, InpSignalTF, 0);
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

int MinutesOfDayUTC(datetime t)
{
   datetime utc = t - InpUtcOffsetMinutes * 60;
   MqlDateTime dt;
   TimeToStruct(utc, dt);
   return dt.hour * 60 + dt.min;
}

bool InTradeWindow(datetime t)
{
   int m = MinutesOfDayUTC(t);
   return (m >= InpTradeStartHourUTC * 60 && m < InpTradeEndHourUTC * 60);
}

bool InAsia(datetime t)
{
   int m = MinutesOfDayUTC(t);
   return (m >= InpAsiaStartHourUTC * 60 && m < InpAsiaEndHourUTC * 60);
}

bool GetATR(double &atr)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, 1, 1, buf) < 1)
      return false;
   atr = buf[0];
   return true;
}

void BuildRange()
{
   int bars = Bars(_Symbol, InpSignalTF);
   double hi = -DBL_MAX;
   double lo = DBL_MAX;

   for(int i = 1; i < bars; i++)
   {
      datetime t = iTime(_Symbol, InpSignalTF, i);
      if(!InAsia(t)) continue;

      hi = MathMax(hi, iHigh(_Symbol, InpSignalTF, i));
      lo = MathMin(lo, iLow(_Symbol, InpSignalTF, i));
   }

   if(hi > lo)
   {
      g_rangeHigh = hi;
      g_rangeLow = lo;
      g_rangeReady = true;
   }
}

bool BreakoutFresh()
{
   if(g_tradeWindowStartBar < 0) return false;

   int currentBars = Bars(_Symbol, InpSignalTF);
   int elapsed = currentBars - g_tradeWindowStartBar;

   return (elapsed <= InpMaxBreakoutBarsFromWindowStart);
}

void TryBreakout(double atr)
{
   if(!BreakoutFresh()) return;

   double high = iHigh(_Symbol, InpSignalTF, 1);
   double low  = iLow(_Symbol, InpSignalTF, 1);
   double close = iClose(_Symbol, InpSignalTF, 1);
   double open  = iOpen(_Symbol, InpSignalTF, 1);
   double range = high - low;

   // BUY breakout
   if(high > g_rangeHigh + InpBreakoutDistanceATR * atr && range > InpBreakoutCandleATR * atr)
   {
      trade.Buy(InpLots);
   }

   // SELL breakout
   if(low < g_rangeLow - InpBreakoutDistanceATR * atr && range > InpBreakoutCandleATR * atr)
   {
      trade.Sell(InpLots);
   }
}

int OnInit()
{
   g_atrHandle = iATR(_Symbol, InpSignalTF, InpATRPeriod);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(!IsNewBar()) return;

   datetime now = TimeCurrent();

   if(!g_rangeReady)
      BuildRange();

   if(!g_rangeReady) return;

   if(InTradeWindow(now))
   {
      if(!g_windowInitialized)
      {
         g_tradeWindowStartBar = Bars(_Symbol, InpSignalTF);
         g_windowInitialized = true;
      }

      double atr;
      if(!GetATR(atr)) return;

      TryBreakout(atr);
   }
   else
   {
      g_windowInitialized = false;
      g_tradeWindowStartBar = -1;
   }
}
