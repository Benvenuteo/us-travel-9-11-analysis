# Dane wejściowe

`raw/sept11n.md` jest kopią tabeli dostarczonej przez użytkownika. `raw/sept11_travel.csv` jest jej bezstratną konwersją do CSV z kropką dziesiętną, przecinkiem jako separatorem i kodowaniem UTF-8.

| Kolumna CSV | Docelowa nazwa w R | Jednostka |
| --- | --- | --- |
| Month | Month | Pierwszy dzień miesiąca, ISO 8601 |
| Air RPM (000s) | Air | Tysiące lotniczych revenue passenger miles |
| Rail PM | Rail | Kolejowe pasażerom mile |
| VMT (billions) | Car | Miliardy mil przebiegu pojazdów drogowych |

Wizualizacje użyją własnych skal i jednostek. Przy prezentacji Air w miliardach pasażerom mil należy podzielić wartość źródłową przez 1 000 000; dla Rail w milionach pasażerom mil przez 1 000 000. VMT pozostaje w miliardach mil pojazdów. Jednostki nie są równoważne.

Źródło pierwotne: [Bureau of Transportation Statistics, Table C1](https://www.bts.gov/archive/publications/estimated_impacts_of_9_11_on_us_travel/table_c01), raport *Estimated Impacts of September 11th on US Travel* (2006).

Zakres i definicje: [rozdział 2](https://www.bts.gov/archive/publications/estimated_impacts_of_9_11_on_us_travel/chapter_02). Dane nie rozdzielają podróży lokalnych i dalekobieżnych.

Analiza wykorzystuje wyłącznie dostarczone 172 kompletne miesiące, 1990-01–2004-04. Nie dołączono późniejszego niekompletnego wiersza widocznego w internetowej tabeli źródłowej.

Data kontroli i konwersji: 2026-10-20. Sumę SHA-256 oryginału i wynik kontroli zapisano w `docs/data-audit.json`. Wartości nie były imputowane ani korygowane.

