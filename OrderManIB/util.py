from settings import s
import math

# Count decimal places : str(tickSize)[::-1].find('.')	
def roundTo10( number:float ):
    return round( number, 10 )

def ceilToTickSize( price:float, tickSize:float ):
    
    div = roundTo10( price/tickSize )                           # Rounding needed to avoid FP accuracy problems
    
    if div.is_integer() :                                       # Already aligned with tick size 
        return price
    else:        
        return  roundTo10( math.ceil( div ) * tickSize ) 

def floorToTickSize( price:float, tickSize:float ):
    
    div = roundTo10( price/tickSize )   
    
    if div.is_integer() :        
        return price
    else:        
        return  roundTo10( math.floor( div ) * tickSize ) 


