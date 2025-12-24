import duckdb
con = duckdb.connect()

q = """SELECT * FROM read_csv_auto('data-all-2022.csv', delim=';', sample_size=-1) WHERE tender_mainCpv LIKE '391%'"""

print('=== ESPLORAZIONE COMPLETA DATI MOBILI 2022 ===')

# 8. Cross-border
print('\n8. OFFERTE NAZIONALI vs CROSS-BORDER')
r = con.execute(f"""
SELECT CASE WHEN tender_country = bidder_country THEN 'Nazionale' ELSE 'Cross-border' END tipo, COUNT(*) n
FROM ({q}) WHERE bidder_country IS NOT NULL
GROUP BY 1
""").fetchall()
for x in r: print(f'   {x[0]}: {x[1]}')

# 9. CPV principali
print('\n9. CPV PIU COMUNI')
r = con.execute(f"""
SELECT tender_mainCpv, COUNT(DISTINCT tender_id) n FROM ({q}) GROUP BY 1 ORDER BY n DESC LIMIT 8
""").fetchall()
for x in r: print(f'   {x[0]}: {x[1]}')

# 10. Prezzi per dimensione gara  
print('\n10. PREZZI PER DIMENSIONE GARA')
r = con.execute(f"""
SELECT tender_size, ROUND(MEDIAN(bid_price_EUR),0) mediana, COUNT(*) n
FROM ({q}) WHERE tender_size IS NOT NULL AND bid_price_EUR > 0 AND bid_price_EUR < 1000000
GROUP BY 1 ORDER BY mediana
""").fetchall()
for x in r: print(f'   {x[0]}: mediana={x[1]:,.0f} EUR (n={x[2]})')

# 11. Prezzi per tipo procedura
print('\n11. PREZZI PER TIPO PROCEDURA')
r = con.execute(f"""
SELECT tender_procedureType, ROUND(MEDIAN(bid_price_EUR),0) mediana, COUNT(*) n
FROM ({q}) WHERE tender_procedureType IS NOT NULL AND bid_price_EUR > 0 AND bid_price_EUR < 1000000
GROUP BY 1 HAVING n > 50 ORDER BY mediana DESC
""").fetchall()
for x in r: print(f'   {x[0]}: mediana={x[1]:,.0f} EUR (n={x[2]})')

# 12. Prezzi per tipo acquirente
print('\n12. PREZZI PER TIPO ACQUIRENTE')
r = con.execute(f"""
SELECT buyer_buyerType, ROUND(MEDIAN(bid_price_EUR),0) mediana, COUNT(*) n
FROM ({q}) WHERE buyer_buyerType IS NOT NULL AND bid_price_EUR > 0 AND bid_price_EUR < 1000000
GROUP BY 1 HAVING n > 50 ORDER BY mediana DESC
""").fetchall()
for x in r: print(f'   {x[0]}: mediana={x[1]:,.0f} EUR (n={x[2]})')

# 13. Competizione calcolata
print('\n13. COMPETIZIONE (bid per lot)')
r = con.execute(f"""
WITH bids_unici AS (
    SELECT DISTINCT tender_id, lot_lotId, bid_row_nr 
    FROM ({q}) WHERE bid_row_nr IS NOT NULL AND lot_lotId IS NOT NULL
),
competizione AS (
    SELECT tender_id, lot_lotId, COUNT(*) as n_bids FROM bids_unici GROUP BY 1,2
)
SELECT n_bids, COUNT(*) n_lots FROM competizione GROUP BY 1 ORDER BY 1 LIMIT 8
""").fetchall()
tot = sum(x[1] for x in r)
for x in r: print(f'   {x[0]} bid: {x[1]} lotti ({x[1]/tot*100:.1f}%)')

# 14. Accordo quadro
print('\n14. ACCORDO QUADRO')
r = con.execute(f"""
SELECT tender_isFrameworkAgreement, COUNT(DISTINCT tender_id) n
FROM ({q}) GROUP BY 1 ORDER BY n DESC
""").fetchall()
for x in r: print(f'   {x[0]}: {x[1]}')

# 15. Prezzo stimato vs offerto
print('\n15. SCONTO (bid vs stima lotto)')
r = con.execute(f"""
SELECT 
    CASE 
        WHEN bid_price_EUR < lot_estimatedPrice_EUR * 0.7 THEN 'Sconto > 30%'
        WHEN bid_price_EUR < lot_estimatedPrice_EUR * 0.9 THEN 'Sconto 10-30%'
        WHEN bid_price_EUR < lot_estimatedPrice_EUR THEN 'Sconto 0-10%'
        WHEN bid_price_EUR = lot_estimatedPrice_EUR THEN 'Prezzo = Stima'
        ELSE 'Sopra stima'
    END categoria, COUNT(*) n
FROM ({q}) 
WHERE bid_price_EUR > 0 AND lot_estimatedPrice_EUR > 0 
  AND bid_price_EUR < 10000000 AND lot_estimatedPrice_EUR < 10000000
GROUP BY 1 ORDER BY n DESC
""").fetchall()
for x in r: print(f'   {x[0]}: {x[1]}')

print('\n=== FINE ESPLORAZIONE ===')
