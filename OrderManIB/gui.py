import tkinter
from tkinter import messagebox


class GUI():
    #def __init__(self):        
    
    def start(self):
        root = tkinter.Tk()
        root.wm_attributes("-topmost", 1)                                                                               # Always on Top

        tkinter.Label(root, text='Entry',  borderwidth=1 ).grid(row=0,column=0)                                         # E/S/T labels
        tkinter.Label(root, text='Stop',   borderwidth=1 ).grid(row=1,column=0)
        tkinter.Label(root, text='Target', borderwidth=1 ).grid(row=2,column=0)

        
        self.guiEntryLabel  = tkinter.Label(root, text=0.0, borderwidth=2, relief="groove" )                             # E/S/T prices
        self.guiStopLabel   = tkinter.Label(root, text=0.0, borderwidth=2, relief="groove" )
        self.guiTargetLabel = tkinter.Label(root, text=0.0, borderwidth=2, relief="groove" )        
        self.guiEntryLabel.grid(row=0,column=1)      
        self.guiStopLabel.grid(row=1,column=1)
        self.guiTargetLabel.grid(row=2,column=1)
        

        self.entryRiskVar = tkinter.StringVar()                                                                         # Entry Qty in terms of ideal risk
        self.entryRiskVar.set( '100' )
        self.entryRiskVar.trace("w", self.onEntryRiskChange)                
        guiEntryRiskPercent = tkinter.Entry(root, textvariable=self.entryRiskVar, width=3 ).grid(row=0,column=2, padx=5)
        
        self.targetRiskVar = tkinter.StringVar()                                                                        # Target Qty in terms of trade risk
        self.targetRiskVar.set( '40' )
        self.targetRiskVar.trace("w", self.onTargetRiskChange)        
        tkinter.Entry(root, textvariable=self.targetRiskVar, width=3 ).grid(row=2,column=2)        

        self.setEntry( 298.05 )
        self.setStop( 296.5 )
        self.setTarget( 301.1 )
        
        root.mainloop()
    
    def pickPrices( self, contractSymbol:str, entryPrice:float, stopPrice:float, targetPrice:float  ):
        self.setEntry( entryPrice  )
        self.setStop( stopPrice )
        self.setTarget( targetPrice )
    
    def setEntry( self, price ):
        self.guiEntryLabel['text'] = price
        
    def setStop( self, price ):
        self.guiStopLabel['text'] = price
        
    def setTarget( self, price ):
        self.guiTargetLabel['text'] = price
        
    def onEntryRiskChange( self, *args ):
        pass        # noop
        #messagebox.showinfo("Hello", self.entryRiskVar.get())
        
    def onTargetRiskChange( self, *args ):        
        pass
        #messagebox.showinfo("Hello", self.targetRiskVar.get())

#GUI().start()

    



