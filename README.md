# Příkazy k zápočtu
# Dokumentace pro databázi

## Připojení k databázi

- sudo -u postgres psql
- psql -U 'uzivatel' -d nazev_databaze -h localhost
- \c elektro

## ERD

- ERDiagram databáze :

[ERD-elektor.pdf](ERD-elektor.pdf)

# Selecty

<aside>
💡

## Select s analytickou funkcí a agregační klauzulí GROUP BY

```sql
SELECT p.nazev AS produkt, ROUND(AVG(h.hodnoceni)) AS prum_hodnoceni
FROM Produkty p
JOIN Hodnoceni h ON p.ID_produktu = h.id_produktu
GROUP BY p.nazev
ORDER BY prum_hodnoceni DESC
LIMIT 5;
```

</aside>

<aside>
💡

## Select v selectu

```sql
SELECT
jmeno, prijmeni,
(SELECT COUNT(*)
FROM Hodnoceni
WHERE Hodnoceni.id_zakaznika = Zakaznici.id_zakaznika) AS pocet_hodnoceni
FROM Zakaznici
WHERE id_zakaznika IN (
SELECT id_zakaznika
FROM Hodnoceni
WHERE hodnoceni = 5
);
```

</aside>

<aside>
💡

## **SELECT vypočítávající průměrný počet záznamů na jednu tabulku v DB**

```sql
SELECT SUM(n_live_tup)/COUNT(*) AS "Průměr" FROM pg_stat_user_tables;
```

</aside>

<aside>
💡

## SELECT řešící rekurzi nebo hierarchii

```sql
WITH RECURSIVE Hierarchie AS (
    SELECT 
        z.id_zamestnance,
        z.jmeno,
        z.prijmeni,
        z.id_pozice,
        z.id_nadrizeneho,
        zp.nazev AS nazev_pozice,
        1 AS uroven
    FROM zamestnanci z
    JOIN zamestnanci_pozice zp ON z.id_pozice = zp.id_pozice
    WHERE z.id_nadrizeneho IS NULL
    UNION ALL
    SELECT 
        z.id_zamestnance,
        z.jmeno,
        z.prijmeni,
        z.id_pozice,
        z.id_nadrizeneho,
        zp.nazev AS nazev_pozice,
        h.uroven + 1 AS uroven
    FROM zamestnanci z
    JOIN zamestnanci_pozice zp ON z.id_pozice = zp.id_pozice
    JOIN Hierarchie h ON z.id_nadrizeneho = h.id_zamestnance
)
SELECT * 
FROM Hierarchie
ORDER BY uroven, id_zamestnance;

```

</aside>

---

# Views

<aside>
💡

## Jeden view

```sql
CREATE VIEW InformaceOProdejnach AS
SELECT
    CONCAT (z.jmeno, ' ', z.prijmeni) AS jmeno_zamestnance,
    z.id_pozice AS zamestnanec_pozice,
    p.adresa AS prodejna_adresa,
    CONCAT (p.jmeno_kontaktni_osoby, ' ', p.prijmeni_kontaktni_osoby) AS kontaktni_osoba,
    ROUND(AVG(h.hodnoceni), 2) AS prumerne_hodnoceni
FROM Zamestnanci z
-- INNER JOIN: Zaměstnanci a jejich prodejny
INNER JOIN Prodejny p ON z.id_prodejny = p.id_prodejny
-- LEFT JOIN: Prodejny s případnými hodnoceními
LEFT JOIN Hodnoceni h ON h.id_produktu = p.id_prodejny -- Pokud produkty odkazují na prodejnu
WHERE z.id_pozice != 5 -- Vynechání managerů
GROUP BY 
    z.jmeno, z.prijmeni, z.id_pozice, 
    p.adresa, p.jmeno_kontaktni_osoby, p.prijmeni_kontaktni_osoby;;
```

</aside>

---

# Indexy

<aside>
💡

## Unikátní index

```sql
CREATE UNIQUE INDEX idx_unique_bankovni_ucet
ON Zamestnanci (bankovni_ucet);
```

</aside>

<aside>
💡

## Fulltextový index

### Vytvoření

```sql
CREATE INDEX idx_fulltext_nazev
ON Produkty USING gin (to_tsvector('simple', nazev));
```

## Použití

```sql
SELECT *
FROM Produkty
WHERE to_tsvector('simple', nazev) @@ plainto_tsquery('Tablet');
```

- použil jsem simple místo czech protože mi nefungovala instalace českého balíčku
</aside>

---

# Funkce

<aside>
💡

## Vytvoření funkce

```sql
CREATE OR REPLACE FUNCTION prum_cena_produktu()
RETURNS NUMERIC AS $$
DECLARE
avg_cena NUMERIC;
BEGIN
SELECT AVG(cena) INTO avg_cena FROM produkty;
RETURN avg_cena;
END;
$$ LANGUAGE plpgsql;
```

## použití

```sql
SELECT prum_cena_produktu();
```

</aside>

---

# Procedure

<aside>
💡

## Vytvoření

- nejříve jsem si pro to vytvořil tabulku

```sql
CREATE TABLE IF NOT EXISTS slevy_na_produkty (
    id_produktu INTEGER PRIMARY KEY,
    nazev TEXT NOT NULL,
    puvodni_cena NUMERIC NOT NULL,
    sleva_v_procentech NUMERIC NOT NULL,
    nova_cena NUMERIC NOT NULL
);
```

```sql
CREATE OR REPLACE PROCEDURE generuj_slevy()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Kurzory pro iteraci přes produkty
    cur_produkty CURSOR FOR SELECT id_produktu, nazev, cena FROM produkty WHERE cena > 1000;
    
    -- Proměnné pro uchovávání dat produktu
    v_id_produktu INTEGER;
    v_nazev TEXT;
    v_cena NUMERIC;

    -- Náhodná sleva (v procentech)
    v_sleva NUMERIC;
BEGIN
    -- Otevření kurzoru
    OPEN cur_produkty;

    LOOP
        -- Načtení dat z kurzoru
        FETCH cur_produkty INTO v_id_produktu, v_nazev, v_cena;

        -- Kontrola, zda jsme na konci kurzoru
        EXIT WHEN NOT FOUND;

        -- Generování náhodné slevy mezi 5 % a 30 %
        v_sleva := ROUND((5 + random() * 25)::numeric, 2);

        -- Ošetření chyb při vkládání dat
        BEGIN
            INSERT INTO slevy_na_produkty (id_produktu, nazev, puvodni_cena, sleva_v_procentech, nova_cena)
            VALUES (
                v_id_produktu,
                v_nazev,
                v_cena,
                v_sleva,
                ROUND(v_cena * (1 - v_sleva / 100), 2)
            );
        EXCEPTION
            WHEN UNIQUE_VIOLATION THEN
                RAISE NOTICE 'Produkt s ID % už byl do tabulky slev přidán, přeskočeno.', v_id_produktu;
            WHEN OTHERS THEN
                RAISE NOTICE 'Chyba při vkládání produktu ID %: %', v_id_produktu, SQLERRM;
        END;
    END LOOP;

    -- Uzavření kurzoru
    CLOSE cur_produkty;

    RAISE NOTICE 'Generování slev bylo úspěšně dokončeno.';
END;
$$;

-- Volání procedury
CALL generuj_slevy();

```

</aside>

<aside>
💡

# Zde v této proceduře použit TRANSACTION

```sql
CREATE OR REPLACE PROCEDURE generuj_slevy()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Kurzory pro iteraci přes produkty
    cur_produkty CURSOR FOR SELECT id_produktu, nazev, cena FROM produkty WHERE cena > 1000;
    
    -- Proměnné pro uchovávání dat produktu
    v_id_produktu INTEGER;
    v_nazev TEXT;
    v_cena NUMERIC;

    
    v_sleva NUMERIC;
BEGIN
    -- Zahájení transakce
    BEGIN
        -- Otevření kurzoru
        OPEN cur_produkty;

        LOOP
            -- Načtení dat z kurzoru
            FETCH cur_produkty INTO v_id_produktu, v_nazev, v_cena;

            -- Kontrola, zda jsme na konci kurzoru
            EXIT WHEN NOT FOUND;

            -- Generování náhodné slevy mezi 5 % a 30 %
            v_sleva := ROUND((5 + random() * 25)::numeric, 2);

            -- Ošetření chyb při vkládání dat
            BEGIN
                INSERT INTO slevy_na_produkty (id_produktu, nazev, puvodni_cena, sleva_v_procentech, nova_cena)
                VALUES (
                    v_id_produktu,
                    v_nazev,
                    v_cena,
                    v_sleva,
                    ROUND(v_cena * (1 - v_sleva / 100), 2)
                );
            EXCEPTION
                WHEN UNIQUE_VIOLATION THEN
                    RAISE NOTICE 'Produkt s ID % už byl do tabulky slev přidán, přeskočeno.', v_id_produktu;
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Chyba při vkládání produktu ID %: %', v_id_produktu, SQLERRM;
            END;
        END LOOP;

        -- Uzavření kurzoru
        CLOSE cur_produkty;

        -- Potvrzení transakce
        COMMIT;
        RAISE NOTICE 'Generování slev bylo úspěšně dokončeno.';
    EXCEPTION
        WHEN OTHERS THEN
            -- V případě chyby vrácení změn
            ROLLBACK;
            RAISE NOTICE 'Transakce byla zrušena kvůli chybě: %', SQLERRM;
    END;
END;
$$;

-- Volání procedury
CALL generuj_slevy();

```

</aside>

---

# Trigger

<aside>
💡

## Nejdříve si pro Trigger vytvoříme tabulku

```sql
CREATE TABLE log_updates (
    id_log SERIAL PRIMARY KEY,
    tabulka TEXT NOT NULL,
    id_zaznamu INTEGER NOT NULL,
    datum_cas TIMESTAMP NOT NULL DEFAULT NOW(),
    uzivatel TEXT NOT NULL
);
```

</aside>

<aside>
💡

## Jakou další si vytvoříme funkci která bude handlovat log systém do tabulky

```sql
CREATE OR REPLACE FUNCTION log_update_function()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO log_updates(tabulka, id_zaznamu, datum_cas, uzivatel)
    VALUES (TG_TABLE_NAME, NEW.id_zamestnance, NOW(), SESSION_USER);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

</aside>

<aside>
💡

## Vytvořím si danný trigger na například tabulku zamestnanci a kdykoliv v této tabulce proběhne nějaký update příkaz tak se to logne do mé log tabulky.

```sql
CREATE TRIGGER after_update_zamestnanci
AFTER UPDATE ON zamestnanci
FOR EACH ROW
EXECUTE FUNCTION log_update_function();
```

</aside>

<aside>
💡

## Ukázka

```sql
UPDATE zamestnanci
SET prijmeni = 'NovéPříjmení'
WHERE id_zamestnance = 16;

```

</aside>

---

# Users

<aside>
💡

## Vytvoření role

```sql
CREATE USER Test_user WITH PASSWORD 'ujep';
```

## Smazání role

```sql
DROP USER Test_user;
```

## Přihlášení

```bash
psql -U Test_user -d nazev_databaze;
```

## Přidělení databáze uživateli

```sql
GRANT CONNECT ON DATABASE nazev_databaze TO Test_user;

-- poté přidělení práv na všechny tabulky v databazi 

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO Test_user;
```

## Vytvoření role

```sql
CREATE ROLE spravce WITH LOGIN CREATEDB CREATEROLE PASSWORD 'ujep';

-- role ktere nema zadne opravneni pro prihlaseni
CREATE ROLE ctenar;

-- smazání role 
DROP ROLE spravce;
DROP ROLE ctenar;
```

## Přiřazení role uživateli

```sql
GRANT spravce TO Test_user;

GRANT ctenar TO Test_user;
```

## Odstranění role uživateli

```sql
REVOKE spravce FROM Test_user;
```

## Omezení práv

```sql
REVOKE ALL PRIVILEGES ON TABLE produkty FROM USER Test_user;
```

## Ukázání jaké jsou u koho práva

```sql
\db

-- pro konktétní tabulku 
\z nazev_tabulky
```

## Změna oprávnění role nebo uživatele

```sql
GRANT CREATEROLE TO Test_user;

REVOKE CREATEROLE TO Test_user;
```

## Příklad nějakého praktického vytvoření

```sql
-- vytvoříme uživatele 
CREATE USER ukazka WITH PASSWORD 'ujep';
-- Vytvoříme pro něj databázi (testovací)
CREATE DATABASE test_database OWNER ukazka;

-- prihlaseni jako tento nový uživatel 
psql -U 'ukazka' -d test_database -h localhost

-- Vytvoření role editor pro tuto databazi
CREATE ROLE editor;
GRANT editor TO ukazka;
GRANT SELECT, INSERT ON TABLE produkty TO ukazka;

-- Náseldné odebrání role a smazani uzivatele 
REVOKE editor FROM ukazka;
DROP USER ukazka;
DROP DATABASE;
```

</aside>

---

# Lock

<aside>
💡

## Zamknutý jen jedné tabulky

```sql
-- zamknutí pro zápis
BEGIN;
LOCK TABLE produkty IN EXCLUSIVE MODE;
COMMIT;

```

</aside>

<aside>
💡

## Transactions

- pro tyto příkazy je ideální využítí transakcí, aby jsem mohli v klidu rollbackout zamknutí daných věcí
</aside>

---

# ORN

<aside>
💡

```python
from sqlalchemy import create_engine, select, Column, Integer, String, Text, ForeignKey, Numeric
from sqlalchemy.orm import declarative_base, sessionmaker

db = create_engine('postgresql://postgres:**********@localhost:5432/elektro')

Base = declarative_base()

class Produkty(Base):
    __tablename__ = 'produkty'

    id_produktu = Column(Integer, primary_key=True)
    nazev = Column(String(100))
    cena = Column(Numeric(10,2))
    pocet_kusu = Column(Integer)
    id_hodnoceni = Column(Integer)

#----------------------------------

Session = sessionmaker(bind=db)
databaze = Session()

produkty = databaze.query(Produkty).all()

def prum_cena_produktu():
    ceny = []
    for x in produkty:
        ceny.append(x.cena)

    print(f"{sum(ceny)/len(ceny)}")

prum_cena_produktu()
```

</aside>
