from settings import s
import database


if __name__ == '__main__':    
    s.useStocksCurrentDB()
    database.deleteDB()

s.useStocksCurrentDB()      # Read again after delete

if __name__ == '__main__':    
    s.createDBIfNeeded()