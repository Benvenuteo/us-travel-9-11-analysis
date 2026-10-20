# Koncepcja i plan: U.S. Travel After 9/11

Data przygotowania: 20 października 2026 r.  
Proponowana nazwa repozytorium: `us-travel-9-11-analysis`.

## 1. Problem, założenia i rezultat

Zbadamy, jak wartości trzech miesięcznych miar transportu po wrześniu 2001 r. różniły się od prognoz opartych wyłącznie na wcześniejszych danych. Raport odpowie na pytania o skalę odchylenia, jego utrzymywanie się i różnice między transportem lotniczym, kolejowym i drogowym.

Podstawowym rezultatem będzie czytelny, samodzielny raport HTML: opis danych, wykresy, porównanie modeli, diagnostyka, oszacowania odchyleń i ograniczenia. Towarzyszyć mu będą kod R, dane, tabele CSV i instrukcja odtworzenia analizy.

Założenie scenariusza porównawczego: bez zakłócenia wcześniejsze prawidłowości mogłyby być przybliżane przez model wybrany na danych sprzed września 2001 r. Jest to założenie modelowe, nie obserwowalny fakt.

Główne okno interpretacyjne obejmie pierwsze 12 miesięcy po zdarzeniu. Pierwsze 3 i 6 miesięcy oraz pełne dostępne 32 miesiące posłużą do pokazania dynamiki. Wraz z horyzontem rośnie niepewność oraz możliwość oddziaływania innych zdarzeń.

## 2. Co już sprawdzono

Odczytano tabelę Markdown dostarczoną przez użytkownika i wykonano kontrolę jej struktury. Zapis CSV zachowuje wartości wejściowe.

| Właściwość | Wynik kontroli |
| --- | --- |
| Zakres | 1990-01–2004-04 |
| Miesiące | 172 |
| Zmienne liczbowe | 3 |
| Obserwacje po przekształceniu do formatu długiego | 516 |
| Brakujące miesiące | 0 |
| Brakujące lub nieskończone wartości liczbowe | 0 |
| Duplikaty miesięcy | 0 |
| Wartości niedodatnie | 0 |
| Przed wrześniem 2001 r. | 140 miesięcy |
| Od września 2001 r. | 32 miesiące |

Wstępny opis: we wrześniu 2001 r. Air był niższy o 30,71% niż we wrześniu 2000 r.; Rail o 0,05%, a Car/VMT o 1,21%. To obliczenia rok do roku, a nie wyniki modeli ani oszacowania efektu przyczynowego.

Źródło pierwotne zidentyfikowano jako tabelę C1 Bureau of Transportation Statistics. Źródłowa strona zawiera także późniejszy, niekompletny wiersz. Analiza pozostanie przy kompletnym zakresie dostarczonym przez użytkownika, do kwietnia 2004 r.

## 3. Definicje zmiennych

| Nazwa robocza | Kolumna oryginalna | Miara i jednostka |
| --- | --- | --- |
| Month | Month | Miesiąc obserwacji |
| Air | Air RPM (000s) | Lotnicze revenue passenger miles w tysiącach |
| Rail | Rail PM | Kolejowe pasażerom mile |
| Car | VMT (billions) | Przebieg pojazdów drogowych w miliardach mil |

Air i Rail mierzą pracę przewozową pasażerów, nie ich liczbę. Car to alias VMT użyty zgodnie z poleceniem; nazwy i podpisy w raporcie będą wskazywać rzeczywiste znaczenie tej miary. Nie będziemy sumować wartości różnych środków transportu. Źródło nie rozdziela ruchu lokalnego i dalekobieżnego, więc tytuł i wnioski obejmą transport ogółem.

## 4. Etapy realizacji

### Krok 1 — Utworzenie i uporządkowanie repozytorium

Docelowe publiczne repozytorium portfolio: `Benvenuteo/us-travel-9-11-analysis`.

Opis: `R time-series study of U.S. travel around 9/11: temporal validation, forecasts and observed-versus-forecast gaps.`

Przygotowanie podstawowej struktury: README, dane surowe, dokumentacja źródeł, projekt RStudio, katalogi R, scripts, reports i outputs. Katalogi z kodem i wynikami powstaną przy implementacji odpowiadających im etapów.

**Rezultat:** repozytorium z jednoznacznym opisem celu i aktualnego stanu.

### Krok 2 — Środowisko i import w R

Utworzenie środowiska R z pakietami używanymi przez fpp3, readr, here i renv oraz raportem Quarto. Instalowanie zależności nastąpi w kroku konfiguracji, a nie przy każdym uruchomieniu analizy. Plik renv.lock powstanie dopiero po rzeczywistym odtworzeniu i sprawdzeniu środowiska.

Wczytanie CSV jako tibble. Jawna zmiana nazw kolumn na Month, Air, Rail, Car, następnie pivot_longer i konwersja Month przez yearmonth. Obiekt tsibble będzie miał klucz Travel i indeks Month.

Sprawdzenie unikalności pary Month–Travel, ciągłości, typów, wartości dodatnich i poprawnej liczby obserwacji. Błąd struktury zatrzyma analizę z czytelnym komunikatem. Nie ma potrzeby imputacji przy obecnym stanie danych.

**Rezultat:** 516 poprawnie zdefiniowanych obserwacji w formacie długim.

### Krok 3 — Eksploracja danych i zależności

Wykresy każdego szeregu z osobną skalą i właściwymi jednostkami; dodatkowo porównanie zmian względnych. Zaznaczenie września 2001 r. i rozróżnienie okresów przed i po zdarzeniu.

Wykresy sezonowe i podszeregów, statystyki opisowe oraz ACF. Wyznaczenie korelacji między szeregami osobno dla poziomów oraz zmian logarytmicznych rok do roku, z pokazaniem okresu sprzed zdarzenia i opisowo okresu późniejszego. Korelacje będą opisowe; wspólny trend i sezonowość mogą zawyżać zależność poziomów.

ACF mierzy zależność szeregu od jego własnej przeszłości i nie zastępuje korelacji Air–Rail–Car. Zmiany rok do roku także mogą pozostawać autokorelacyjne, dlatego proste testy istotności korelacji nie będą podstawą wnioskowania.

Obserwacje odstające zostaną opisane i sprawdzone jako możliwe błędy danych lub rzeczywiste zdarzenia. Spadek z września 2001 r. pozostaje w analizie jako centralny przedmiot badania.

**Rezultat:** krótka charakterystyka trendu, sezonowości i współzmienności.

### Krok 4 — Podział i reguły walidacji

Końcowy zbiór uczący: 1990-01–2001-08. Okres porównania po zdarzeniu: 2001-09–2004-04. Wrzesień traktujemy jako miesiąc zdarzenia; dane miesięczne nie rozdzielają dni przed i po 11 września.

Wewnątrz zbioru sprzed zdarzenia zastosujemy walidację z rosnącym oknem: start od 60 miesięcy, przesunięcie punktu startowego prognozy co 3 miesiące. Każda oceniana prognoza i wszystkie jej dane uczące zakończą się najpóźniej w sierpniu 2001 r.

Główny ranking będzie oparty na średniej MASE dla horyzontów 1–12 miesięcy, przy wspólnym zestawie dostępnych początków prognoz. Dodatkowa ocena horyzontów 24 i 32 miesięcy pokaże ograniczenia długiej ekstrapolacji; dla tych horyzontów użyjemy wyłącznie początków z kompletem późniejszych obserwacji sprzed zdarzenia.

Wybór specyfikacji, transformacji i modelu nie będzie wykorzystywał wyników po wrześniu 2001 r. W każdej iteracji walidacji przekształcenia i estymacja modelu korzystają tylko z danego okna uczącego.

**Rezultat:** jawny protokół oceny bez informacji z przyszłości.

### Krok 5 — Dekompozycja STL

Dekompozycja na trend, sezonowość i resztę na próbie uczącej. Ocena wizualna stałości amplitudy sezonowej: addytywność lub ewentualna zasadność logarytmowania, bez dodatkowych testów wymagających rozbudowy zadania.

STL w zwykłej skali jest addytywne; STL po logarytmowaniu może opisywać wzorce multiplikatywne. Wyjaśnimy tę różnicę w raporcie. Gdy transformacja jest częścią modelu prognozującego, wybierzemy ją wyłącznie w walidacji sprzed zdarzenia i wrócimy z prognozami do oryginalnej skali.

**Rezultat:** wykresy STL i uzasadniony opis struktury szeregów.

### Krok 6 — Sześć metod prognozowania

Obowiązkowe punkty odniesienia: Mean, Naive, SNaive i Drift. Dwa rozszerzenia: ETS oraz sezonowa ARIMA. Będą oceniane na tych samych podziałach, osobno dla każdego środka transportu.

Automatyczny dobór specyfikacji ETS i ARIMA będzie wykonywany wewnątrz próby uczącej każdej iteracji. Unikniemy ręcznego przeglądania dziesiątek wariantów na podstawie wyników po zdarzeniu.

**Rezultat:** porównanie prostych metod i dwóch standardowych modeli sezonowych.

### Krok 7 — Ocena modeli i diagnostyka reszt

Tabele RMSE, MAE, MAPE i MASE dla dopasowania oraz prognoz walidacyjnych. MASE będzie skalowane sezonowym błędem naiwnym z opóźnieniem 12, obliczonym wyłącznie z odpowiedniego zbioru uczącego.

Najlepszy model dla każdego szeregu wybierzemy według uprzednio zdefiniowanego kryterium walidacji. Osiągnięcie MASE poniżej 1 odnosi się do skali błędu sezonowo naiwnego w danych uczących; rzeczywistą poprawę względem SNaive w walidacji ocenimy także bezpośrednio, na tych samych miesiącach.

Dla wybranego modelu pokażemy przebieg reszt, histogram, ACF oraz test Ljunga–Boxa dla opóźnienia 24 z dostosowaniem stopni swobody do modelu. Diagnostyka dotyczy próby sprzed zdarzenia, a jej niekorzystny wynik zostanie opisany jako ograniczenie prognoz.

Ocena błędów po zdarzeniu będzie dodatkową, osobno oznaczoną tabelą. Nie posłuży do późniejszej zmiany modelu scenariusza porównawczego. Model dobrze trafiający w spadek po zamachach nie musi prawidłowo reprezentować wcześniejszego wzorca.

**Rezultat:** audytowalny wybór modeli i opis ograniczeń ich reszt.

### Krok 8 — Prognozy i oszacowanie odchyleń

Ponowna estymacja wybranego modelu każdego szeregu na pełnych 140 miesiącach sprzed zdarzenia. Prognozy zostaną dopasowane do konkretnych dat w okresie późniejszym, zamiast wyliczania horyzontu jako liczby wierszy podzielonej przez trzy.

W raporcie pokażemy wszystkie cztery metody z zadania na jednym układzie wykresów oraz osobny czytelny wykres wybranego modelu z danymi rzeczywistymi i miesięcznymi przedziałami predykcji 80% i 95%.

Definicje:
- Gap = Actual - Forecast.
- GapPct = 100 × (Actual - Forecast) / Forecast.
- Skumulowane odchylenie = suma Gap w zadanym oknie.
- Względne odchylenie skumulowane = 100 × suma Gap / suma Forecast.

Wartość ujemna oznacza poziom niższy od prognozy. Procenty wymagają dodatniej prognozy; niepoprawny mianownik zostanie wykryty i opisany. Sumy zostaną policzone odrębnie dla każdego szeregu, w jego jednostkach. Miesięcznych granic przedziałów nie będziemy sumować jako przedziału dla skumulowanego wyniku.

Porównanie obejmie 3, 6, 12 i 32 miesiące. Utrzymywanie się odchylenia opiszemy jego ścieżką i położeniem obserwacji względem prognozy, bez utożsamiania wejścia do szerokiego przedziału z pełną odbudową transportu.

**Rezultat:** tabele i wykresy skali odchylenia, z wyraźnym rozdzieleniem obserwacji i scenariusza modelowego.

### Krok 9 — Prosta analiza wrażliwości i interpretacja

Sprawdzimy, czy główny wniosek dla pierwszych 12 miesięcy utrzymuje się przy SNaive oraz modelu wybranym z ETS i ARIMA. Dodatkowo można porównać pełną próbę uczącą z jej ostatnimi 60 miesiącami, przy zachowaniu tych samych zasad oceny sprzed zdarzenia.

Wnioski obejmą odpowiedzi na pytania badawcze, znaczenie praktyczne i ograniczenia. Samo współwystępowanie spadku Air i zmian pozostałych miar nie dowodzi substytucji. Brak grupy kontrolnej, miesięczna agregacja i inne czynniki gospodarcze ograniczają interpretację przyczynową.

**Rezultat:** wnioski proporcjonalne do danych, niewymagające rozbudowy projektu o dodatkowe systemy modelowe.

### Krok 10 — Raport i publikacja portfolio

Raport Quarto zapisany jako samodzielny HTML, z osadzonymi ilustracjami i poprawnym UTF-8. README będzie prowadzić do raportu i wyjaśniać cel, dane, metodologię, wyniki oraz polecenia uruchomienia.

Dołączenie tabel CSV, wykresów PNG, sprawdzonego renv.lock i informacji o środowisku. Jedno polecenie uruchomi analizę, a drugie wyrenderuje raport; dokładne polecenia zostaną ustalone wraz z działającą implementacją.

Kontrola na czystej sesji R: odczyt danych, spójność dat, brak nakładania prób, właściwe skale MASE, liczba prognoz, kompletność raportu i działanie odnośników. Weryfikacja wizualna wykresów, polskich znaków i otwierania raportu bez dostępu do zewnętrznych obrazów.

**Rezultat:** gotowy projekt portfolio z rzeczywistymi wynikami i odtwarzalną analizą.

## 5. Kryteria ukończenia

1. Każdy wynik liczbowy wynika z kodu R i dostarczonych danych.
2. Źródła, zakres i jednostki są jawnie udokumentowane.
3. Model scenariusza porównawczego jest wybierany bez danych po zdarzeniu.
4. Cztery metody wymagane w zadaniu i dwa rozszerzenia mają wspólną, uczciwą ocenę.
5. Raport zawiera prognozy z niepewnością, diagnostykę i ograniczenia.
6. Wszystkie pliki raportu są czytelne i mają poprawne polskie znaki.
7. Projekt uruchamia się według instrukcji w czystym środowisku.
8. Wyniki pozostają kompletne również wtedy, gdy ETS lub ARIMA nie przewyższą prostej metody odniesienia.

## 6. Co podnosi poziom projektu

O jakości stanowią poprawne jednostki, walidacja czasowa, oddzielenie wyboru modelu od oceny okresu po zdarzeniu, diagnostyka, jawna niepewność i odtwarzalność. Zakres pozostaje niewielki: sześć metod, trzy szeregi i jeden spójny raport.

## 7. Źródła metodologii i danych

- BTS, tabela C1: https://www.bts.gov/archive/publications/estimated_impacts_of_9_11_on_us_travel/table_c01
- BTS, rozdział 2: https://www.bts.gov/archive/publications/estimated_impacts_of_9_11_on_us_travel/chapter_02
- BTS, rozdział 3, kontekst innych determinant transportu: https://www.bts.gov/archive/publications/estimated_impacts_of_9_11_on_us_travel/chapter_03
- Hyndman i Athanasopoulos, Forecasting: Principles and Practice: https://otexts.com/fpp3/toolbox.html
- Dokumentacja narzędzi graficznych ggtime: https://github.com/mitchelloharawild/ggtime

## 8. Stan realizacji

Repozytorium utworzono na koncie Benvenuteo. Protokół i dane opublikowano przed ukończeniem obliczeń. Zrealizowano analizę w R, walidację, porównanie modeli, diagnostykę, analizę wrażliwości i raport HTML.

Wyniki: [raport HTML](../reports/travel_9_11.html), [tabele CSV](../outputs/tables/) i [README](../README.md). Zakres ARIMA i ETS pozostał w oryginalnej skali; nie dodawano siatki transformacji. Analiza wrażliwości porównuje sześć metod i długie horyzonty. Opcjonalne porównanie z oknem ostatnich 60 miesięcy nie było potrzebne do realizacji przyjętego zakresu.

Zweryfikowane środowisko: R 4.5.1 i Quarto 1.8.27; wersje pakietów zachowano w renv.lock. Wyniki nie są identyfikowanym przyczynowo efektem zamachów.
