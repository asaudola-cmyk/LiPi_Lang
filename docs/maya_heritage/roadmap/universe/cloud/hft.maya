@! ============================================================================
@! MAYA UNIVERSE CLOUD - HFT (HIGH-FREQUENCY TRADING) CORE (universe/cloud/hft.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"

@fn array_shift(arr)
  res = []
  i = 1
  @while i < arr.len()
    res = res.push(arr[i])
    i = i + 1
  @end
  return res
@end

@! Represents an Order Book
@fn orderbook_new(symbol)
  return {
    symbol: symbol,
    bids: [], @! Buy orders, sorted desc
    asks: [], @! Sell orders, sorted asc
    trades: []
  }
@end

@! Order struct
@fn order_new(id, side, price, qty)
  return {
    id: id,
    side: side, @! "BUY" or "SELL"
    price: price,
    qty: qty,
    timestamp: 0 @! System time
  }
@end

@! Add Order to Book (Simplified Matching Engine)
@fn orderbook_add(book, order)
  @if order.side == "BUY"
    @! Check if we can cross with asks
    continue_matching = 1
    @while order.qty > 0 && book.asks.len() > 0 && continue_matching == 1
      best_ask = book.asks[0]
      @if order.price >= best_ask.price
        @! Match!
        trade_qty = order.qty
        @if best_ask.qty < order.qty
          trade_qty = best_ask.qty
        @end
        
        book.trades = book.trades.push({ price: best_ask.price, qty: trade_qty })
        
        order.qty = order.qty - trade_qty
        best_ask.qty = best_ask.qty - trade_qty
        
        @if best_ask.qty == 0
          @! Remove matched best ask
          book.asks = array_shift(book.asks)
        @else
          book.asks = list_set(book.asks, 0, best_ask)
        @end
      @else
        continue_matching = 0
      @end
    @end
    
    @if order.qty > 0
      book.bids = book.bids.push(order)
    @end
  @else
    @! Sell order logic
    continue_matching = 1
    @while order.qty > 0 && book.bids.len() > 0 && continue_matching == 1
      best_bid = book.bids[0]
      @if order.price <= best_bid.price
        trade_qty = order.qty
        @if best_bid.qty < order.qty
          trade_qty = best_bid.qty
        @end
        
        book.trades = book.trades.push({ price: best_bid.price, qty: trade_qty })
        
        order.qty = order.qty - trade_qty
        best_bid.qty = best_bid.qty - trade_qty
        
        @if best_bid.qty == 0
          book.bids = array_shift(book.bids)
        @else
          book.bids = list_set(book.bids, 0, best_bid)
        @end
      @else
        continue_matching = 0
      @end
    @end
    
    @if order.qty > 0
      book.asks = book.asks.push(order)
    @end
  @end
  
  return book
@end
