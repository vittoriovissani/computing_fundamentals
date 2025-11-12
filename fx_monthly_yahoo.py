# -*- coding: utf-8 -*-
"""
Script: fx_monthly_yahoo.py

Descrizione
-----------
Scarica automaticamente i tassi di cambio giornalieri da Yahoo Finance tramite la libreria `yfinance`
per le coppie USD/{GHS, KES, NGN, RWF, UGX, ZAR, ZMW} e calcola la media **mensile** (unità di valuta per 1 USD).

Vantaggi
- ✅ Gratuito, nessuna chiave API
- ✅ Copertura storica ampia
- ✅ Output in formato "wide" e "long" (CSV)

Dipendenze
- Python 3.8+
- pandas
- yfinance

Installazione (una volta sola):
    pip install pandas yfinance

Esecuzione (esempio):
    python fx_monthly_yahoo.py --start 2020-01-01 --end 2025-12-31 --out monthly_fx

Questo creerà:
    monthly_fx_wide.csv  -> colonne per ogni valuta (unità per USD)
    monthly_fx_long.csv  -> (data, currency, rate)

Note importanti
- Yahoo Finance fornisce dati a scopo informativo. Per uso accademico/analitico va bene; per scopi
  contabili/contrattuali considera fonti ufficiali (banche centrali, FMI).
- Alcune valute (p.es. RWF, UGX) possono avere variazioni giornaliere limitate o scalini;
  è normale per regimi amministrati.
"""

import argparse
from datetime import datetime
from typing import Dict, List, Tuple

import pandas as pd

try:
    import yfinance as yf
except ImportError as e:
    raise SystemExit("La libreria 'yfinance' non è installata. Esegui: pip install yfinance")

# Mapping principale: ticker Yahoo -> codice valuta ISO
DEFAULT_TICKERS: Dict[str, str] = {
    # Yahoo usa il formato "XXX=X" per indicare USD/XXX
    "GHS=X": "GHS",
    "KES=X": "KES",
    "NGN=X": "NGN",
    "RWF=X": "RWF",
    "UGX=X": "UGX",
    "ZAR=X": "ZAR",
    "ZMW=X": "ZMW",
}

# Alcune coppie hanno anche l'alias esplicito "USDXXX=X"; lo teniamo come fallback
FALLBACK_TICKERS: Dict[str, str] = {
    "USDGHS=X": "GHS",
    "USDKES=X": "KES",
    "USDNGN=X": "NGN",
    "USDRWF=X": "RWF",
    "USDUGX=X": "UGX",
    "USDZAR=X": "ZAR",
    "USDZMW=X": "ZMW",
}


def _download_group(tickers: List[str], start: str, end: str) -> pd.DataFrame:
    """Scarica i dati giornalieri (OHLC) per un gruppo di ticker con yfinance.download.

    Ritorna un DataFrame con colonne MultiIndex [campo][ticker] e indice datetime.
    """
    if not tickers:
        return pd.DataFrame()
    df = yf.download(
        tickers=tickers,
        start=start,
        end=end,
        interval="1d",
        group_by="column",  # mantiene colonne con suffisso ticker
        auto_adjust=False,
        threads=True,
        progress=False,
    )
    return df


def _extract_close_to_wide(df: pd.DataFrame, ticker_to_ccy: Dict[str, str]) -> pd.DataFrame:
    """Estrae i prezzi di chiusura e rinomina le colonne con i codici valuta ISO.

    Accetta sia DataFrame a colonne MultiIndex (campo, ticker) sia ampie con 'Close-<TICKER>'.
    """
    if df.empty:
        return df

    # Se df ha MultiIndex (campo, ticker)
    if isinstance(df.columns, pd.MultiIndex):
        # Normalizziamo al livello ('Close', ticker)
        if "Close" not in df.columns.get_level_values(0):
            raise ValueError("Nel dataset scaricato non è presente la colonna 'Close'.")
        close = df["Close"].copy()
        close = close.rename(columns={t: ticker_to_ccy.get(t, t) for t in close.columns})
        return close

    # In alcuni casi yfinance può restituire colonne piatte con suffissi
    cols = {}
    for c in df.columns:
        if c.startswith("Close"):
            # Formati possibili: 'Close', 'Close_GHS=X', 'GHS=X Close'
            if "_" in c:
                t = c.split("_")[1]
            elif " " in c:
                t = c.split(" ")[0]
            else:
                t = None
            if t:
                cols[c] = ticker_to_ccy.get(t, t)
    if cols:
        close = df[list(cols.keys())].rename(columns=cols)
        return close

    raise ValueError("Impossibile identificare le colonne di chiusura per i ticker richiesti.")


def compute_monthly_average(close_wide: pd.DataFrame) -> pd.DataFrame:
    """Calcola la media mensile delle chiusure (unità di valuta per 1 USD).

    Restituisce due DataFrame:
      - wide: indice mensile, colonne = valute
    """
    # Resample a inizio mese per date pulite (media dei giorni del mese)
    monthly = close_wide.resample("MS").mean()
    monthly.index.name = "date"
    return monthly


def wide_to_long(monthly_wide: pd.DataFrame) -> pd.DataFrame:
    long_df = (
        monthly_wide.reset_index()
        .melt(id_vars=["date"], var_name="currency", value_name="rate_units_per_usd")
        .sort_values(["currency", "date"])  # ordinamento ordinato
    )
    return long_df


def main(start: str, end: str, out_prefix: str, include_usd: bool = True) -> Tuple[pd.DataFrame, pd.DataFrame]:
    # 1) Scarico set principale
    df_main = _download_group(list(DEFAULT_TICKERS.keys()), start, end)
    close_main = _extract_close_to_wide(df_main, DEFAULT_TICKERS)

    # 2) Identifico eventuali colonne mancanti e provo fallback
    missing_ccy = [iso for iso in DEFAULT_TICKERS.values() if iso not in close_main.columns]

    if missing_ccy:
        fb_map = {t: c for t, c in FALLBACK_TICKERS.items() if c in missing_ccy}
        if fb_map:
            df_fb = _download_group(list(fb_map.keys()), start, end)
            if not df_fb.empty:
                close_fb = _extract_close_to_wide(df_fb, fb_map)
                # unisco (priorità ai dati già presenti)
                for col in close_fb.columns:
                    if col not in close_main.columns:
                        close_main[col] = close_fb[col]

    # 3) Aggiungo USD=1 come riferimento opzionale
    if include_usd:
        close_main["USD"] = 1.0

    # 4) Ordino colonne secondo una lista nota
    desired_order = ["GHS", "KES", "NGN", "RWF", "UGX", "ZAR", "ZMW"] + (["USD"] if include_usd else [])
    cols = [c for c in desired_order if c in close_main.columns] + [
        c for c in close_main.columns if c not in desired_order
    ]
    close_main = close_main[cols]

    # 5) Calcolo mensile (media)
    monthly_wide = compute_monthly_average(close_main)

    # 6) Converto in long
    monthly_long = wide_to_long(monthly_wide)

    # 7) Salvo CSV
    wide_path = f"{out_prefix}_wide.csv"
    long_path = f"{out_prefix}_long.csv"
    monthly_wide.to_csv(wide_path, index=True)
    monthly_long.to_csv(long_path, index=False)

    print(f"Salvati:\n - {wide_path}\n - {long_path}")
    return monthly_wide, monthly_long


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scarica FX mensili (media) da Yahoo Finance con yfinance.")
    parser.add_argument("--start", type=str, default="2020-01-01", help="Data inizio (YYYY-MM-DD)")
    parser.add_argument("--end", type=str, default=datetime.today().strftime("%Y-%m-%d"), help="Data fine (YYYY-MM-DD)")
    parser.add_argument("--out", type=str, default="monthly_fx", help="Prefisso file di output (senza estensione)")
    parser.add_argument("--no-usd", action="store_true", help="Non includere la colonna USD=1.0")

    args = parser.parse_args()
    main(args.start, args.end, args.out, include_usd=not args.no_usd)
