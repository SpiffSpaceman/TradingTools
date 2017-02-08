/*
  Copyright (C) 2015  SpiffSpaceman

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

class ContextClass{
	
    currentIndex := -1
    trades       := Object()
    guiData      := Object()
    

       
    init(){
        this.resetContext(1)
        this.resetContext(2)
        this.resetContext(3)
        
        this.currentIndex := 1
    }

    getCurrentIndex(){
        return this.currentIndex
    }
    
    getCurrentTrade(){
        return this.trades[this.currentIndex]
	}
    
    getTradeAt( i ){
        return this.trades[i]
    }
    
    getAllTrades(){
        return this.trades
    }
            
    switchContext( newIndex ){
        
        if( newIndex == this.currentIndex )
            return

        this._saveCurrentContext()        
        this.currentIndex := newIndex
        this._loadCurrentContext()
    }
    
    /* Switch to another trade if input scrip found else do nothing
    */
    switchContextByScrip( scrip ){
        for index, data in this.guiData {
            if( data.hasData && data.SelectedScripText == scrip  ){
                this.switchContext( index )
                return
            }
        }
    }
    
    /* Just switch index without saving and loading to GUI
        Used on Startup while loading saved orders
    */
    switchContextIndex( newIndex){        
        this.currentIndex := newIndex
    }
    
    resetContext( index ){
        this.trades[index]          := new TradeClass 
        this.guiData[index]         := Object()
        this.guiData[index].hasData := false
        
        if( this.currentIndex == index  ){                          // update GUI if trade is currently in context
            clearGUI()
        }
    }

    /*  Saves trade data to guiData, used in initial load to avoid udpatingGUI multiple times
        This combines loadTradeInputToGui() and _saveCurrentContext()
    */
    loadTradeToContext(){
        global contextObj, InitialStopDistance, InitialEntry

        trade  		:= contextObj.getCurrentTrade()
        scripAlias	:= trade.scrip.alias
        entry  		:= trade.newEntryOrder
        entryInput  := entry.getInput()
        stop  		:= trade.stopOrder
        target	    := trade.target

        InitialStopDistance	 := trade.InitialStopDistance
        InitialEntry 		 := trade.InitialEntry
                
        this._saveGuiData( entryInput.qty, entry.getPrice(), stop.getPrice(), target.getPrice(), target.getGUIQty(), entryInput.direction, entryInput.orderType, scripAlias, InitialStopDistance, InitialEntry )
    }

// --- Allow GUI updates from trade that is out of current context --- 
    
    /* After Entry/Add order is filled or cancelled, refresh targetQtyPerc to new Position size without changing Target Qty 
       ie update ratio while keeping actual TargetQty unchanged, any Target size increase has to be manually triggered
       If trade is out of context, no change needed as context load will update TargetQtyPerc from TargetQty
    */
    refreshTargetQtyPercFromContext( i ){
        global TargetQty
        if( i == this.currentIndex ){
			setTargetQty( TargetQty )
        }
    }

    clearQtyFromContext( i ){
        if( i == this.currentIndex )
			setQty( 0 )												         // Remove Qty from GUI
        else if ( this.guiData[i].hasData )
            this.guiData[i].Qty := 0                                         // Else clear it in saved context
    }
    
    clearTargetQtyFromContext( i ){
        if( i == this.currentIndex )
			setTargetQty( 0 )												 // Remove Target Qty from GUI
        else if ( this.guiData[i].hasData )
            this.guiData[i].TargetQty := 0                                   // Else clear it in saved context
    }
    
    
    
    
    /* Save Current Context, save GUI data which may not have been saved in trade yet
    */
    _saveCurrentContext(){
        global Qty, EntryPrice, StopPrice, TargetPrice, TargetQty, Direction, EntryOrderType, SelectedScripText, InitialStopDistance, InitialEntry
        
        this._saveGuiData( Qty, EntryPrice, StopPrice, TargetPrice, TargetQty, Direction, EntryOrderType, SelectedScripText, InitialStopDistance, InitialEntry ) 
    }
    
    _saveGuiData( qty, entryPrice, stopPrice, targetPrice, targetQty, direction, entryOrderType, selectedScripText, initialStopDistance, initialEntry ){
        i := this.currentIndex 
        
        this.guiData[i].hasData            := true
        this.guiData[i].Qty                := qty
        this.guiData[i].EntryPrice         := entryPrice
        this.guiData[i].StopPrice          := stopPrice
        this.guiData[i].TargetPrice        := targetPrice
        this.guiData[i].TargetQty          := targetQty
        this.guiData[i].Direction          := direction
        this.guiData[i].EntryOrderType     := entryOrderType
        this.guiData[i].SelectedScripText  := selectedScripText
        
        this.guiData[i].InitialStopDistance  := initialStopDistance
        this.guiData[i].InitialEntry         := initialEntry
    }
    
    /* Load saved GUI data to GUI
       Similar to loadTradeInputToGui(), but cannot take from trade as data may have been updated or trade may not have been created yet
    */
    _loadCurrentContext(){      
      global InitialStopDistance, InitialEntry, isTimerActive

      i := this.currentIndex 
      
      if( this.guiData[i].hasData ){                            // Load saved GUI data, this may have been changed but not yet saved to trade
          x := this.guiData[i]
          setSelectedScrip( x.SelectedScripText )
          setGUIValues( x.Qty, x.EntryPrice, x.StopPrice, x.TargetPrice, x.TargetQty, x.Direction, x.EntryOrderType  )
          InitialStopDistance  := this.guiData[i].InitialStopDistance
          InitialEntry         := this.guiData[i].InitialEntry
      }
      else{
          clearGUI()
      }
      updateCurrentResult() 

      if( !isTimerActive  )
        updateStatus()
    }
}
