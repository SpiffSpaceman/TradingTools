from lxml import html
import datetime
import glob
import pandas as pd
import shutil

from settings  import s

#Tradelog fields - "Date"  "ExpenseAmt"

def _parseCost( filepath ):
    with open(filepath, 'r') as f:
        htmltxt = f.read()

    tree         = html.fromstring( htmltxt )

    payinTable   = tree.xpath( "//table[@bordercolor='maroon']" )[0]                  # 1st table with attribute bordercolor == maroon
    grossRow     = payinTable.xpath( "tr[./td//text()[contains(.,'PAY IN/')]]" )[0]   # Select tr with child td that has a text element that contains "PAY IN"
    netRow       = payinTable.xpath( "tr[./td//text()[contains(.,'Net Amount receivable by Client/')]]" )[0]

    gross        = float( grossRow.xpath( "td[2]/text()"  )[0] )                      # Select text of 2nd column
    net          = float( netRow.xpath( "td[2]/text()"  )[0] )
    tax          = round( gross - net, 2 )

    date         = str(tree.xpath("//tr[./th/text()='TRADE DATE']/td[1]/text()")[0])  # 'tr' that contains a 'th' with text = 'TRADE DATE'. Take text of 1st td within such tr
    date         = datetime.datetime.strptime( date , '%d-%m-%Y' ).strftime('%Y-%m-%d')

    return date, tax

def readContractNotes():
    files       = glob.glob( s.CN_SOURCE_PATH )
    logChanged  = False

    if( len(files) > 0 ) :
        file   = open(s.TRADE_LOG, 'r')
        trades = pd.read_csv(file)
        file.close()

    for file in files :
        date, cost          = _parseCost( file )                                        # Returns CN date and total expense for the day

        tradeLogRows        = trades['Date'] == date                                    # Rows in tradelog that match CN date
        tradeLogRowsCount   = len(tradeLogRows[tradeLogRows == True] )

        if( tradeLogRowsCount > 0 ):
            trades.loc[tradeLogRows, ['ExpenseAmt']] = cost/tradeLogRowsCount           # Update avg Costs in Tradelog
            logChanged = True
            shutil.move( file, s.CN_DEST_PATH )                                         # move CN to target folder

    if( logChanged ):
        trades.to_csv(s.TRADE_LOG, index=False)                                         # Update Tradelog csv


