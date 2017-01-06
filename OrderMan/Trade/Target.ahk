/*
  Copyright (C) 2016  SpiffSpaceman

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>
*/

/*
	Current Target Order + Array of executed target orders
*/
class TargetClass{

    openOrder         := -1
    executedOrderList := []
	
	guiQty			  := 0														// Save qty entered in GUI separately as target order qty depends on open position size
																				// Saving GUI qty will allow context change to other orders without loosing input target qty
	fillQty			  := 0														// Keeps Track of partial fills to update stop
  
    /* Creates/updates/deletes Target Limit order based on input target price
	   Entry and stop order must be ready before calling this
	*/
	handleTargetOrder( _targetPrice, _targetQty, _stopOrder, _openPositionSize ){
		global ORDER_TYPE_GUI_LIMIT	
		
		if( (_targetPrice == 0  ||  _targetPrice == "" || _targetQty == 0 ) ){
			this.openOrder.cancel()											    // Cancel if open. Can happen for adds, If target cleared, cancel it
			this.resetOpenOrder()
			return
		}

        _scrip          := _stopOrder.getInput().scrip
		_stopDirection  := _stopOrder.getInput().direction
		_prodType	    := _stopOrder.getInput().prodType
		_stopPrice	    := _stopOrder.getPrice()
        _entryDirection := UtilClass.reverseDirection( _stopDirection )

		if( !IsObject( this.openOrder ) ){
			this.openOrder := new OrderClass
		}
        
        _qty := _targetQty >= _openPositionSize ? _openPositionSize : _targetQty // Target size cannot be more than open position
																				 // Create/Update Target Limit Order - Target always covers only current Executed position
		this.guiQty := _targetQty
		
		if( !this._validateTargetPrice( _entryDirection, _stopPrice, _targetPrice) ){
			UtilClass.conditionalMessage( false, "Bug - _handleTargetOrder() validation failure" )
			return
		}

		this.openOrder.setOrderInput( ORDER_TYPE_GUI_LIMIT, _stopDirection, _qty, _targetPrice, 0, _prodType, _scrip )
																				// Setup input params. Also used to update GUI
		if( _qty == 0 ) 											            // Keep Target order pending until we have Entered a position
			return
		
		if( this.openOrder.isCreated )
			this.openOrder.update()
		else
			this.openOrder.create()
	}

	/* Load Target order with input Orderbook data
	*/
	loadTarget( _orderDetails ){
		
		if( !IsObject(_orderDetails) )
			return
		
		this.openOrder := new OrderClass
		this.openOrder.loadOrderFromOrderbook( _orderDetails )
		
		if( this.guiQty < this.getOrderQty() )									// If GUI qty is not set, use target order qty
			this.guiQty := this.getOrderQty()
		
		this.fillQty := this.openOrder.getFilledQty()
	}

	/* Create/Update Target Order after Entry/Add order is Filled
	*/
	onEntrySuccessful( _stopOrder, _openPositionSize ){
		this.handleTargetOrder( this.getPrice(), this.getGUIQty(), _stopOrder, _openPositionSize )
	}
	
    /* Callback from Trade on open order completion
    */
    onTargetClose( tradeIndex ){
		global contextObj
		
        if( this.isTargetSuccessful() )
			this.executedOrderList.Push( this.openOrder )
        this.resetOpenOrder()
		
		contextObj.clearTargetQtyFromContext( tradeIndex )						// Remove Target Qty from trade
    }

    /* Cancel open order
    */
    cancel(){
		if( this.openOrder.cancel() ){
			this.resetOpenOrder()
			return true
		}
		return false
    }

	/* Reset Linked orders
	*/
	unlink(){
		this.resetOpenOrder()
		this.executedOrderList := []
	}

	/* Clears Open order links
	*/
	resetOpenOrder(){
		this.openOrder := -1
		this.guiQty	   := 0
		this.fillQty   := 0
	}

	/* checks if Target was filled partially
	   Returns incremental filled qty, returns 0 if no change
	*/
	isPartiallyFilled(){
		newFillQty 		:= this.openOrder.getFilledQty()
		incrementalFill := newFillQty - this.fillQty							// How much got filled since last check
		
		if( incrementalFill > 0 ){
			this.fillQty := newFillQty											// update Fill size for next call
		}
		
		return incrementalFill
	}

    getOpenOrder(){
        return this.openOrder
    }
    
    /* Returns open target Order price
    */
    getPrice(){
        return this.openOrder.getPrice()
    }

	/* Returns qty used in open/pending target order. Target Qty in GUI can be different
	*/
	getOrderQty(){
		return this.openOrder.getInput().qty
	}

	/* Returns target qty entered in GUI
	*/
	getGUIQty(){
		return this.guiQty
	}

	/*	Indicates whether Target Order has status = complete
		Note this wont remain true for too long. We will unlink open order in onTargetClose()
		This is meant for use in callback
	*/
	isTargetSuccessful(){		
		return  IsObject( this.openOrder ) && this.openOrder.isComplete()
	}
	
	/* Is an open target order linked with trade
	*/
	isLinked(){
		return IsObject( this.openOrder ) && this.openOrder.isLinked()
	}

	getExecutedOrderList(){
		list := ""
		For index, value in this.executedOrderList{
			list := list . value.getOrderDetails().nowOrderNo . ","
		}
		return list
	}

  	/* For Buy order - Target Price should be more than open stop order
	*/
	_validateTargetPrice( direction, stopPrice, targetPrice  ){
		return direction == "B" ? targetPrice > stopPrice : targetPrice < stopPrice	
	}

}