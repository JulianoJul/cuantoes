import sys
import json
import datetime
import re
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


URL = "https://www.bcv.org.ve/"

# Venezuela = UTC-4 (sin horario de verano)
_OFFSET_VENEZUELA = datetime.timedelta(hours=4)


FERIADOS_FIJOS = {
    (1, 1),     # Ano Nuevo
    (19, 4),    # Declaracion de la Independencia
    (1, 5),     # Dia del Trabajador
    (24, 6),    # Batalla de Carabobo
    (5, 7),     # Dia de la Independencia
    (24, 10),   # Natalicio de Jose Gregorio Hernandez
    (25, 12),   # Navidad
    (31, 12),   # Fin de ano
}

# Dias festivos moviles base (se calculan por ano)
FERIADOS_MOVILES_NOMBRE = ("carnaval_lunes", "carnaval_martes",
                           "jueves_santo", "viernes_santo")


def _pascua(year):
    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    mes = (h + l - 7 * m + 114) // 31
    dia = ((h + l - 7 * m + 114) % 31) + 1
    return datetime.date(year, mes, dia)


def _feriados_moviles(year):
    pascua = _pascua(year)
    return {
        pascua - datetime.timedelta(days=48),  # carnaval lunes
        pascua - datetime.timedelta(days=47),  # carnaval martes
        pascua - datetime.timedelta(days=3),   # jueves santo
        pascua - datetime.timedelta(days=2),   # viernes santo
    }


def _es_feriado(fecha):
    if (fecha.day, fecha.month) in FERIADOS_FIJOS:
        return True
    return fecha in _feriados_moviles(fecha.year)


def _siguiente_dia_habil(fecha):
    d = fecha
    while d.weekday() >= 5 or _es_feriado(d):
        d += datetime.timedelta(days=1)
    return d


def _ahora_venezuela():
    """Hora actual en Venezuela (UTC-4), independiente de la zona del sistema."""
    return datetime.datetime.utcnow() - _OFFSET_VENEZUELA


def _fecha_efectiva():
    """Fecha efectiva BCV según la hora actual en Venezuela."""
    ahora = _ahora_venezuela()
    ef = datetime.datetime(ahora.year, ahora.month, ahora.day)
    if ahora.hour >= 14:
        ef += datetime.timedelta(days=1)
    return _siguiente_dia_habil(ef)


def _parsear_tasa(texto):
    return texto.replace("\n", "").replace(" ", "").replace(".", "").replace(",", ".")


MESES = {
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4,
    "mayo": 5, "junio": 6, "julio": 7, "agosto": 8,
    "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
}


def _parsear_fecha_valor(texto):
    if not texto:
        return None

    normalizado = texto.lower().replace(",", " ")
    match = re.search(
        r"(\d{1,2})\s+(?:de\s+)?(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+(?:de\s+)?(\d{4})",
        normalizado,
    )
    if match:
        try:
            return datetime.date(
                int(match.group(3)), MESES[match.group(2)], int(match.group(1))
            )
        except ValueError:
            return None

    palabras = [p for p in re.split(r"\s+", normalizado) if p]
    for i in range(len(palabras) - 2):
        dia = palabras[i]
        mes = MESES.get(palabras[i + 1])
        anio = palabras[i + 2]
        if mes is None or not dia.isdigit() or not anio.isdigit():
            continue
        try:
            return datetime.date(int(anio), mes, int(dia))
        except ValueError:
            return None

    match = re.search(r"(\d{1,2})[/-](\d{1,2})[/-](\d{4})", texto)
    if match:
        try:
            return datetime.date(
                int(match.group(3)), int(match.group(2)), int(match.group(1))
            )
        except ValueError:
            return None
    return None


def scrape_bcv():
    options = Options()
    options.add_argument("--headless")
    options.set_preference("intl.accept_languages", "es-ES")
    options.set_preference("general.useragent.override", (
        "Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"
    ))

    driver = webdriver.Firefox(options=options)
    try:
        driver.get(URL)
        WebDriverWait(driver, 15).until(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )

        rows = driver.find_elements(By.CSS_SELECTOR, "div.row")
        if not rows:
            print(json.dumps({"error": "No se encontraron filas en la pagina"}))
            sys.exit(1)

        tasas = {}
        fecha_texto = None
        for row in rows:
            texto = row.text.strip()
            if not texto:
                continue
            lineas = [l.strip() for l in texto.splitlines() if l.strip()]
            for i, linea in enumerate(lineas):
                if linea in ("USD", "EUR", "CNY", "TRY", "RUB") and i + 1 < len(lineas):
                    tasas[linea] = _parsear_tasa(lineas[i + 1])
                if "Fecha Valor" in linea or "fecha valor" in linea.lower():
                    fecha_texto = linea

        if "USD" not in tasas:
            print(json.dumps({"error": "No se encontro la tasa USD"}))
            sys.exit(1)

        captura = _ahora_venezuela()
        fecha_valor = _parsear_fecha_valor(fecha_texto)
        ef = fecha_valor or _fecha_efectiva().date()
        fecha_iso = ef.strftime("%Y-%m-%dT00:00:00")
        captura_iso = captura.isoformat()

        out = {
            "usd": float(tasas["USD"]),
            "eur": float(tasas.get("EUR", 0)),
            "usdt": 0,
            "fecha": captura_iso,
            "fecha_efectiva": fecha_iso,
            "fecha_valor_bcv": fecha_texto or "",
            "origen": "scraping",
            "fuente": URL,
        }

        print(json.dumps(out, ensure_ascii=False, indent=2))

    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.exit(1)
    finally:
        driver.quit()


if __name__ == "__main__":
    scrape_bcv()
