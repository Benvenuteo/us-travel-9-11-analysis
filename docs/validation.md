# Kontrola końcowa projektu

Data: 20 października 2026 r. Środowisko: R 4.5.1, Quarto 1.8.27.

## Analiza i testy

- Obliczono sześć metod dla każdego z trzech szeregów.
- Walidacja obejmuje 23 kompletne okna dla horyzontów 1–12 i 17 pełnych okien 32-miesięcznych.
- Wszystkie obserwacje walidacyjne poprzedzają wrzesień 2001 r. i następują po swoich punktach prognozy.
- Testy: 8 scenariuszy i 29 asercji, bez błędów i pominiętych testów po wykonaniu analizy.
- Sprawdzono ręczne przykłady RMSE, MAE, MAPE, MASE oraz ważonego odchylenia skumulowanego.
- Potwierdzono 576 prognoz po zdarzeniu, 96 obserwacji dla wybranych modeli oraz poprawną kolejność granic przedziałów.
- `renv::status()` potwierdza spójność środowiska i pliku blokady.

## Raport

- Zweryfikowano integralność wszystkich 20 plików PNG.
- Raport zawiera 20 poprawnie wyświetlanych, osadzonych wykresów oraz 16 tabel.
- Dwa wzory są zapisane jako natywny MathML, bez zewnętrznych bibliotek matematycznych.
- Test w przeglądarce z zablokowanymi żądaniami internetowymi: brak błędów JavaScript i brak prób pobierania zasobów.
- Nie wykryto uszkodzonych znaków Unicode ani poziomego przepełnienia strony przy szerokości 1440 pikseli.
- Sprawdzono wizualnie początek raportu, tabele walidacji, diagnostykę i wzory.

## Ograniczenia statystyczne pozostają jawne

Autokorelacja reszt sezonowej metody naiwnej dla kolei oraz niższe od nominalnego pokrycie przedziałów dla ruchu drogowego są opisane w raporcie. Ostrzeżenia wykonania zachowano w `outputs/results/analysis-warnings.txt`. Przejście kontroli technicznych nie oznacza potwierdzenia identyfikacji przyczynowej.

## Odtworzenie

Po odtworzeniu środowiska wykonaj z katalogu głównego:

```bash
Rscript scripts/run_analysis.R
Rscript scripts/test.R
quarto render reports/travel_9_11.qmd
```

Wykresy można odtworzyć z lokalnego pliku wynikowego bez ponawiania walidacji: `Rscript scripts/render_figures.R`.
