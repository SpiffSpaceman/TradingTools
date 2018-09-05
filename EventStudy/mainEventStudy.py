import os
import sys

os.chdir(sys.path[0])                               # Set working dir

from settings import s
import eventStudy as es
import signals as sig
import indicators as ind


def signal(scrip, bars):
    sig.scrip = scrip
    sig.bars  = bars

    #signal = sig.trendUp() & sig.KBTopClose()
    #signal = sig.trendDown() & sig.KBBottomClose()
    
    #signal = sig.trendUp() & sig.donchianLong()

    #signal =  sig.trendUp() & sig.newHOD() 
    #signal = sig.trendDown() & sig.newLOD()
    
    
    #signal = sig.trendUp() & sig.spikeUp( 1 )  & ~sig.KBTopClose() & sig.emaCloseAbove();
    #signal = sig.trendUp() & sig.spikeUp( 1 )  & sig.KBTopClose();
   
    
    #signal = sig.trendDown() & sig.spikeDown( 1 ) & ~sig.KBBottomClose() & sig.emaCloseBelow();
    #signal = sig.trendDown() & sig.spikeDown( 1 ) & sig.KBBottomClose();
    
    #signal = sig.trendDown() & sig.KBBottomClose();
    #signal = sig.trendDown() & sig.newLOD() & sig.spikeDown( 1 )
    
    signal = sig.spikeDown( 5 )  
    
    #signal = sig.trendUp() & sig.spikeUp( 5 )    
    #signal = sig.trendDown() & sig.spikeDown( 5 )
    
    #signal = sig.trendUp() & sig.nBarRunUp(3)  & sig.spikeUp( 2 )   
    #signal = sig.trendDown() & sig.nBarRunDown(3)  & sig.spikeDown( 2 )   
    
    
    return signal

def signal2(scrip, bars):
    sig.scrip = scrip
    sig.bars = bars

    signal = sig.trendDown() & sig.newLOD()
    return signal

def tests():
    s.setSignalFunction(signal)
    
    s.FILTER_NEAR_SIGNALS = False
    #s.EXPORT_TRADES       = True    
    s.MULTIPROC           = False
    
    s.useStocksDB()
    #s.useNiftyIndexDB()
    #s.useBankNiftyIndexDB()
    #s.enableRandomDB()

    #testByTime()
    #testByTimeYearlySplit()

    s.setTimeFilter('1000', '1430')
    test('1000-1430')
    
    #s.setTimeFilter('1100', '1430')
    #test('1100-1430')
    
    #
    # s.setSignalFunction(signal2)
    # s.setTimeFilter('1000', '1430')
    # test('1000-1430')

# -----------------------------------------------------------------

def testByTimeYearlySplit():
    print('\n --- 2013 --- \n')
    s.setDateFilter('20130101','20131231')
    testByTime()

    print('\n --- 2014 --- \n')
    s.setDateFilter('20140101', '20141231')
    testByTime()

    print('\n --- 2015 --- \n')
    s.setDateFilter('20150101', '20151231')
    testByTime()

    print('\n --- 2016 --- \n')
    s.setDateFilter('20160101', '20161231')
    testByTime()

    print('\n --- 2017 --- \n')
    s.setDateFilter('20170101', '20171231')
    testByTime()

def testByTime():
    s.setTimeFilter( '1000','1430' )
    test('1000-1430')

    s.setTimeFilter('0915', '1000')
    test('0915-1000')

    s.setTimeFilter('1000', '1100')
    test('1000-1100')

    s.setTimeFilter('1100', '1200')
    test('1100-1200')

    s.setTimeFilter('1200', '1330')
    test('1200-1330')

    s.setTimeFilter('1330', '1430')
    test('1330-1430')


def testOpenHour():
    s.setTimeFilter( '0915','1330' )
    test('0915-1330')

    s.setTimeFilter('0915', '0930')
    test('0915-0930')

    s.setTimeFilter('0930', '0945')
    test('0930-0945')

    s.setTimeFilter('0945', '1000')
    test('0945-1000')

    s.setTimeFilter('1000', '1015')
    test('1000-1015')

def randomCompare():
    s.setTimeFilter('0915', '1430')
    test('ALL 0915-1430')

    s.enableRandomDB() 
    test('RANDOM')

# -----------------------------------------------------------------

def test( msg = ''):
    if __name__ == '__main__':        
        print('\n --- ' + msg + ' --- \n')
        s.createDBIfNeeded()                # Has to be run from main for MP to work under windows
        es.doEventStudy()


try:
    if __name__ == '__main__':
        es.init()

    tests()

    if __name__ == '__main__':
        es.finit()

except BaseException as e:
    import traceback
    exc_type, exc_value, exc_traceback = sys.exc_info()

    print( traceback.format_exc() )
    print( exc_type )
    print( exc_value )

    es.finit()

    raise e
    
