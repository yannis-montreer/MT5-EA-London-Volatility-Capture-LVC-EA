# Asia-London Range Expansion EA (MT5)

## Overview

This project implements a fully systematic trading strategy for MetaTrader 5 based on a simple but powerful idea:

> Markets tend to consolidate during the Asia session and expand during the London session.

The EA identifies the Asia range and then trades the expansion phase using strictly defined, quantitative rules. The system is designed to remove discretion and operate using volatility, time, and price structure only.

It is primarily built and optimized for **XAUUSD (Gold)** on the **M5 timeframe**.

---

## Core Idea

The strategy models the market in two phases:

### 1. Accumulation (Asia Session)

During the Asia session (00:00–06:00 UTC), price typically forms a range.

The EA records:

* The highest price (range high)
* The lowest price (range low)

This defines the **Asia range**.

---

### 2. Expansion (London Session)

When London opens (07:00–10:00 UTC), volatility increases.

The strategy looks for three possible outcomes when price interacts with the range:

1. **True breakout** → continuation
2. **Breakout + retest** → continuation after confirmation
3. **Breakout + reversal** → liquidity grab then move opposite

---

## Strategy Components

### 1. Volatility Normalization (ATR)

All thresholds are expressed relative to ATR (Average True Range).

This allows the system to adapt automatically to:

* high volatility environments
* low volatility environments

ATR is used for:

* breakout strength
* candle expansion
* retest depth
* reversal detection
* stop loss and take profit

This ensures the strategy remains consistent across different market conditions.

---

### 2. Time-Based Logic (Critical Edge)

Time is a core part of the strategy.

The EA enforces:

* Breakouts must occur early in the London session
* Retests must happen within a limited number of candles
* Reversals must be fast (strong displacement)

This avoids:

* late, low-quality breakouts
* slow, indecisive price action

---

### 3. Range Quality Filter

The Asia range must be valid relative to ATR:

* Too small → noise → ignored
* Too large → already expanded → ignored

This ensures only meaningful consolidation phases are traded.

---

### 4. Breakout Freshness

A breakout is only valid if it happens within a limited number of candles after the London session opens.

This reflects the fact that:

> The best moves happen early, when liquidity enters the market.

Late breakouts are ignored.

---

### 5. Recent Extreme Bias (Liquidity Context)

The EA analyzes where the range was last formed:

* If the Asia session ends near the **high**:

  * Liquidity above is likely targeted first
  * Immediate short breakouts are filtered

* If the Asia session ends near the **low**:

  * Liquidity below is likely targeted first
  * Immediate long breakouts are filtered

This prevents entering low-probability trades and allows the system to favor:

* continuation
* or sweep → reversal setups

---

## Entry Models

### 1. True Breakout

Conditions:

* Price breaks beyond the range by a minimum ATR threshold
* Breakout candle shows strong expansion
* Occurs early in the London session

Entry:

* At candle close

Logic:

> Market accepts price outside the range → continuation

---

### 2. Breakout + Retest

Conditions:

* Breakout occurs
* Price returns to the breakout level
* Retest happens quickly
* Price holds the level

Entry:

* On confirmation of the hold

Logic:

> Market confirms breakout before continuing

---

### 3. Breakout + Reversal (Liquidity Sweep)

Conditions:

* Price breaks the range (liquidity grab)
* Moves beyond by ATR threshold
* Quickly returns inside the range
* Strong displacement in opposite direction

Entry:

* On re-entry or confirmation candle

Logic:

> Breakout traders are trapped → market moves opposite

---

## Entry Priority

The EA evaluates setups in the following order:

1. Reversal (highest priority)
2. Retest
3. True breakout

This prioritization reflects observed market behavior:

* failed moves often create stronger opportunities
* confirmed setups are preferred over raw breakouts

---

## Risk Management

The system includes:

* ATR-based stop loss
* Configurable risk-reward ratio
* Optional ATR-based take profit
* Optional range projection targets
* Optional risk-based position sizing

---

## Inputs (Key Parameters)

The EA is fully configurable for optimization.

Main parameter groups:

### Volatility

* ATR period
* ATR timeframe

### Breakout

* Minimum breakout distance (ATR)
* Minimum candle size (ATR)

### Retest

* Maximum delay (bars)
* Depth of retest (ATR)

### Reversal

* Overshoot (ATR)
* Return move (ATR)

### Time

* Session definitions (UTC)
* Maximum breakout delay (bars)

### Bias Filter

* Recent extreme lookback
* Opposite breakout blocking duration

### Risk

* Fixed lot or % risk
* SL / TP multipliers

---

## How to Use

1. Attach the EA to **XAUUSD**
2. Use **M5 timeframe**
3. Set correct **UTC offset** for your broker
4. Run backtests in Strategy Tester
5. Optimize parameters if needed

---

## Design Philosophy

This strategy is built around three principles:

### 1. Remove Subjectivity

Everything is rule-based:

* no visual judgment
* no discretion
* no "feels like"

---

### 2. Normalize Everything

All thresholds use ATR:

* ensures consistency
* adapts to volatility

---

### 3. Trade Only High-Quality Conditions

The system avoids:

* late moves
* weak breakouts
* noisy ranges

---

## Roadmap

* [ ] Spread filter
* [ ] News filter
* [ ] Trailing stop / breakeven
* [ ] Visualization (range + signals)
* [ ] Multi-symbol support

---

## Disclaimer

This project is for research and educational purposes only. It does not constitute financial advice. Trading involves risk, and you are responsible for your own d
