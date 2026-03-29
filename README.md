# Asia-London Range Expansion EA (MT5)

## Overview

This project implements a systematic Expert Advisor (EA) for MetaTrader 5 based on the Asia session range and London session volatility expansion, primarily designed for XAUUSD.

The strategy is fully rule-based and uses ATR-normalized thresholds, time constraints, and liquidity context to trade three core scenarios:

* True breakout
* Breakout + retest
* Breakout + reversal (liquidity sweep)

---

## Strategy Logic

### 1. Session Model

* Asia session: 00:00 – 06:00 UTC
* London session (trade window): 07:00 – 10:00 UTC

The EA builds the Asia range using the highest high and lowest low during the Asia session.

---

### 2. Core Concepts

#### Breakout

Price exits the Asia range with sufficient strength (ATR-based).

#### Retest

Price breaks the range, then returns to the level and holds before continuing.

#### Reversal (Fake Breakout)

Price breaks the range, takes liquidity, then re-enters and moves in the opposite direction.

---

### 3. Filters

#### Volatility (ATR)

All distances and thresholds are normalized using ATR to adapt to market conditions.

#### Time (Freshness)

* Breakouts must occur early in the London session
* Retests and reversals must happen within a limited number of candles

#### Range Quality

* Avoids ranges that are too small or too large relative to ATR

#### Recent Extreme Bias

* If Asia ends near the high → avoids immediate short breakout
* If Asia ends near the low → avoids immediate long breakout
* Can favor liquidity sweep + reversal in these cases

---

## Entry Types

### 1. True Breakout

* Strong breakout beyond range
* Entry on confirmed breakout candle

### 2. Breakout + Retest

* Breakout occurs
* Price revisits level within defined time window
* Entry on confirmation of hold

### 3. Breakout + Reversal

* Breakout exceeds range (liquidity grab)
* Price re-enters range quickly
* Entry in opposite direction

---

## Risk Management

* ATR-based Stop Loss
* Configurable Risk:Reward or ATR targets
* Optional risk-based position sizing
* One position per symbol (optional)

---

## Inputs (Key Parameters)

* ATR period and timeframe
* Breakout distance (ATR multiple)
* Retest timing and depth
* Reversal overshoot and return thresholds
* Session times (UTC-based)
* Breakout freshness (max bars from session open)
* Recent extreme bias settings

---

## How to Use

1. Attach the EA to XAUUSD
2. Use M5 timeframe (recommended)
3. Set correct UTC offset for your broker
4. Run in Strategy Tester before live usage
5. Optimize parameters if needed

---

## Roadmap

* [ ] Spread filter
* [ ] News filter
* [ ] Trailing stop / breakeven
* [ ] On-chart visualization of range and signals
* [ ] Multi-symbol support

---

## Disclaimer

This project is for research and educational purposes only. It does not constitute financial advice. Trading involves risk and you are responsible for your own decisions.
