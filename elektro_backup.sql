--
-- PostgreSQL database dump
--

-- Dumped from database version 14.15 (Ubuntu 14.15-1.pgdg22.04+1)
-- Dumped by pg_dump version 14.15 (Ubuntu 14.15-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: generuj_slevy(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.generuj_slevy()
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


ALTER PROCEDURE public.generuj_slevy() OWNER TO postgres;

--
-- Name: log_update_function(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_update_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO log_updates(tabulka, id_zaznamu, datum_cas, uzivatel)
    VALUES (TG_TABLE_NAME, NEW.id_zamestnance, NOW(), SESSION_USER);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_update_function() OWNER TO postgres;

--
-- Name: prum_cena_produktu(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prum_cena_produktu() RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    avg_cena NUMERIC;
BEGIN
    SELECT AVG(cena) INTO avg_cena FROM produkty;
    RETURN avg_cena;
END;
$$;


ALTER FUNCTION public.prum_cena_produktu() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dopravci; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dopravci (
    id_dopravce integer NOT NULL,
    nazev character varying(100)
);


ALTER TABLE public.dopravci OWNER TO postgres;

--
-- Name: dopravci_id_dopravce_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dopravci_id_dopravce_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dopravci_id_dopravce_seq OWNER TO postgres;

--
-- Name: dopravci_id_dopravce_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dopravci_id_dopravce_seq OWNED BY public.dopravci.id_dopravce;


--
-- Name: hodnoceni; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hodnoceni (
    id_hodnoceni integer NOT NULL,
    id_zakaznika integer,
    hodnoceni integer,
    id_produktu integer
);


ALTER TABLE public.hodnoceni OWNER TO postgres;

--
-- Name: hodnoceni_id_hodnoceni_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.hodnoceni_id_hodnoceni_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hodnoceni_id_hodnoceni_seq OWNER TO postgres;

--
-- Name: hodnoceni_id_hodnoceni_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.hodnoceni_id_hodnoceni_seq OWNED BY public.hodnoceni.id_hodnoceni;


--
-- Name: prodejny; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prodejny (
    id_prodejny integer NOT NULL,
    adresa text,
    jmeno_kontaktni_osoby character varying(100),
    prijmeni_kontaktni_osoby character varying(100),
    telefoni_cislo character varying(20)
);


ALTER TABLE public.prodejny OWNER TO postgres;

--
-- Name: zamestnanci; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zamestnanci (
    id_zamestnance integer NOT NULL,
    jmeno character varying(50),
    prijmeni character varying(50),
    id_pozice integer,
    id_prodejny integer,
    bankovni_ucet character varying(50),
    id_nadrizeneho integer
);


ALTER TABLE public.zamestnanci OWNER TO postgres;

--
-- Name: informaceoprodejnach; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.informaceoprodejnach AS
 SELECT z.jmeno AS zamestnanec_jmeno,
    z.prijmeni AS zamestnanec_prijmeni,
    z.id_pozice AS zamestnanec_pozice,
    p.adresa AS prodejna_adresa,
    p.jmeno_kontaktni_osoby AS kontaktni_osoba_jmeno,
    p.prijmeni_kontaktni_osoby AS kontaktni_osoba_prijmeni,
    round(avg(h.hodnoceni), 2) AS prumerne_hodnoceni
   FROM ((public.zamestnanci z
     JOIN public.prodejny p ON ((z.id_prodejny = p.id_prodejny)))
     LEFT JOIN public.hodnoceni h ON ((h.id_produktu = p.id_prodejny)))
  WHERE (z.id_pozice <> 3)
  GROUP BY z.jmeno, z.prijmeni, z.id_pozice, p.adresa, p.jmeno_kontaktni_osoby, p.prijmeni_kontaktni_osoby;


ALTER TABLE public.informaceoprodejnach OWNER TO postgres;

--
-- Name: log_updates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.log_updates (
    id_log integer NOT NULL,
    tabulka text NOT NULL,
    id_zaznamu integer NOT NULL,
    datum_cas timestamp without time zone DEFAULT now() NOT NULL,
    uzivatel text NOT NULL
);


ALTER TABLE public.log_updates OWNER TO postgres;

--
-- Name: log_updates_id_log_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.log_updates_id_log_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_updates_id_log_seq OWNER TO postgres;

--
-- Name: log_updates_id_log_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.log_updates_id_log_seq OWNED BY public.log_updates.id_log;


--
-- Name: objednavky; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.objednavky (
    id_objednavky integer NOT NULL,
    cena_objednavky numeric(10,2),
    id_zakaznika integer,
    zaplaceno boolean,
    id_dopravce integer,
    vyzvednuto boolean,
    datum_cas timestamp without time zone
);


ALTER TABLE public.objednavky OWNER TO postgres;

--
-- Name: objednavky_id_objednavky_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.objednavky_id_objednavky_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.objednavky_id_objednavky_seq OWNER TO postgres;

--
-- Name: objednavky_id_objednavky_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.objednavky_id_objednavky_seq OWNED BY public.objednavky.id_objednavky;


--
-- Name: prehled_zam; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.prehled_zam AS
 SELECT z.jmeno,
    z.prijmeni,
    p.adresa AS adresa_prodejny
   FROM (public.zamestnanci z
     JOIN public.prodejny p ON ((z.id_prodejny = p.id_prodejny)));


ALTER TABLE public.prehled_zam OWNER TO postgres;

--
-- Name: prodejny_id_prodejny_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prodejny_id_prodejny_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.prodejny_id_prodejny_seq OWNER TO postgres;

--
-- Name: prodejny_id_prodejny_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prodejny_id_prodejny_seq OWNED BY public.prodejny.id_prodejny;


--
-- Name: produkty; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.produkty (
    id_produktu integer NOT NULL,
    nazev character varying(100),
    cena numeric(10,2),
    pocet_kusu integer,
    id_hodnoceni integer
);


ALTER TABLE public.produkty OWNER TO postgres;

--
-- Name: produkty_id_produktu_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.produkty_id_produktu_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.produkty_id_produktu_seq OWNER TO postgres;

--
-- Name: produkty_id_produktu_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.produkty_id_produktu_seq OWNED BY public.produkty.id_produktu;


--
-- Name: produkty_objednavky; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.produkty_objednavky (
    id_produktu integer NOT NULL,
    id_objednavka integer NOT NULL,
    pocet_kusu integer
);


ALTER TABLE public.produkty_objednavky OWNER TO postgres;

--
-- Name: reklamace; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reklamace (
    id_reklamace integer NOT NULL,
    id_produktu integer,
    id_zakaznika integer,
    duvod text,
    datum_cas timestamp without time zone,
    id_prodejny integer
);


ALTER TABLE public.reklamace OWNER TO postgres;

--
-- Name: reklamace_id_reklamace_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reklamace_id_reklamace_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reklamace_id_reklamace_seq OWNER TO postgres;

--
-- Name: reklamace_id_reklamace_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reklamace_id_reklamace_seq OWNED BY public.reklamace.id_reklamace;


--
-- Name: slevy_na_produkty; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.slevy_na_produkty (
    id_produktu integer NOT NULL,
    nazev text NOT NULL,
    puvodni_cena numeric NOT NULL,
    sleva_v_procentech numeric NOT NULL,
    nova_cena numeric NOT NULL
);


ALTER TABLE public.slevy_na_produkty OWNER TO postgres;

--
-- Name: zakaznici; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zakaznici (
    id_zakaznika integer NOT NULL,
    jmeno character varying(50),
    prijmeni character varying(50),
    email character varying(100),
    heslo character varying(100),
    adresa text
);


ALTER TABLE public.zakaznici OWNER TO postgres;

--
-- Name: zakaznici_id_zakaznika_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zakaznici_id_zakaznika_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zakaznici_id_zakaznika_seq OWNER TO postgres;

--
-- Name: zakaznici_id_zakaznika_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zakaznici_id_zakaznika_seq OWNED BY public.zakaznici.id_zakaznika;


--
-- Name: zamestnanci_id_zamestnance_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zamestnanci_id_zamestnance_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zamestnanci_id_zamestnance_seq OWNER TO postgres;

--
-- Name: zamestnanci_id_zamestnance_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zamestnanci_id_zamestnance_seq OWNED BY public.zamestnanci.id_zamestnance;


--
-- Name: zamestnanci_pozice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zamestnanci_pozice (
    id_pozice integer NOT NULL,
    nazev character varying(50)
);


ALTER TABLE public.zamestnanci_pozice OWNER TO postgres;

--
-- Name: zamestnanci_pozice_id_pozice_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zamestnanci_pozice_id_pozice_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zamestnanci_pozice_id_pozice_seq OWNER TO postgres;

--
-- Name: zamestnanci_pozice_id_pozice_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zamestnanci_pozice_id_pozice_seq OWNED BY public.zamestnanci_pozice.id_pozice;


--
-- Name: dopravci id_dopravce; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dopravci ALTER COLUMN id_dopravce SET DEFAULT nextval('public.dopravci_id_dopravce_seq'::regclass);


--
-- Name: hodnoceni id_hodnoceni; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hodnoceni ALTER COLUMN id_hodnoceni SET DEFAULT nextval('public.hodnoceni_id_hodnoceni_seq'::regclass);


--
-- Name: log_updates id_log; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_updates ALTER COLUMN id_log SET DEFAULT nextval('public.log_updates_id_log_seq'::regclass);


--
-- Name: objednavky id_objednavky; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.objednavky ALTER COLUMN id_objednavky SET DEFAULT nextval('public.objednavky_id_objednavky_seq'::regclass);


--
-- Name: prodejny id_prodejny; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prodejny ALTER COLUMN id_prodejny SET DEFAULT nextval('public.prodejny_id_prodejny_seq'::regclass);


--
-- Name: produkty id_produktu; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.produkty ALTER COLUMN id_produktu SET DEFAULT nextval('public.produkty_id_produktu_seq'::regclass);


--
-- Name: reklamace id_reklamace; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reklamace ALTER COLUMN id_reklamace SET DEFAULT nextval('public.reklamace_id_reklamace_seq'::regclass);


--
-- Name: zakaznici id_zakaznika; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zakaznici ALTER COLUMN id_zakaznika SET DEFAULT nextval('public.zakaznici_id_zakaznika_seq'::regclass);


--
-- Name: zamestnanci id_zamestnance; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zamestnanci ALTER COLUMN id_zamestnance SET DEFAULT nextval('public.zamestnanci_id_zamestnance_seq'::regclass);


--
-- Name: zamestnanci_pozice id_pozice; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zamestnanci_pozice ALTER COLUMN id_pozice SET DEFAULT nextval('public.zamestnanci_pozice_id_pozice_seq'::regclass);


--
-- Data for Name: dopravci; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dopravci (id_dopravce, nazev) FROM stdin;
1	DHL
2	PPL
3	Česká pošta
4	DPD
5	WEDO
\.


--
-- Data for Name: hodnoceni; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hodnoceni (id_hodnoceni, id_zakaznika, hodnoceni, id_produktu) FROM stdin;
1	1	5	1
2	2	4	2
3	3	3	3
4	4	5	4
5	5	4	5
6	6	5	6
7	7	4	7
8	8	3	8
9	9	5	9
10	10	4	10
11	11	3	11
12	12	5	12
13	13	4	13
14	14	3	14
15	15	5	15
16	16	4	16
17	17	3	17
18	18	5	18
19	19	4	19
20	20	3	20
\.


--
-- Data for Name: log_updates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.log_updates (id_log, tabulka, id_zaznamu, datum_cas, uzivatel) FROM stdin;
1	zamestnanci	1	2025-01-15 10:58:40.225386	postgres
2	zamestnanci	5	2025-02-04 08:31:08.670904	postgres
3	zamestnanci	5	2025-02-04 08:32:03.153491	postgres
4	zamestnanci	5	2025-02-04 08:32:07.517162	postgres
5	zamestnanci	4	2025-02-04 13:33:35.760044	postgres
6	zamestnanci	9	2025-02-04 13:33:35.769187	postgres
7	zamestnanci	14	2025-02-04 13:33:35.772018	postgres
8	zamestnanci	19	2025-02-04 13:33:35.775073	postgres
9	zamestnanci	3	2025-02-04 13:33:35.778004	postgres
10	zamestnanci	8	2025-02-04 13:33:35.781363	postgres
11	zamestnanci	13	2025-02-04 13:33:35.783841	postgres
12	zamestnanci	18	2025-02-04 13:33:35.786206	postgres
13	zamestnanci	2	2025-02-04 13:33:35.78875	postgres
14	zamestnanci	7	2025-02-04 13:33:35.79128	postgres
15	zamestnanci	12	2025-02-04 13:33:35.793422	postgres
16	zamestnanci	17	2025-02-04 13:33:35.795514	postgres
17	zamestnanci	6	2025-02-04 13:33:35.79775	postgres
18	zamestnanci	11	2025-02-04 13:33:35.800493	postgres
19	zamestnanci	16	2025-02-04 13:33:35.8033	postgres
20	zamestnanci	1	2025-02-04 13:33:35.805993	postgres
21	zamestnanci	16	2025-02-04 14:32:07.16302	postgres
\.


--
-- Data for Name: objednavky; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.objednavky (id_objednavky, cena_objednavky, id_zakaznika, zaplaceno, id_dopravce, vyzvednuto, datum_cas) FROM stdin;
1	1200.00	8	t	1	f	2024-01-15 10:30:00
2	1000.00	9	t	4	t	2024-02-20 15:45:00
3	1000.00	3	f	3	f	2024-03-05 08:15:00
4	700.00	1	t	5	t	2024-04-10 09:00:00
5	3000.00	10	t	2	f	2024-05-25 11:45:00
6	500.00	5	f	3	t	2024-06-18 14:20:00
7	2000.00	7	t	1	f	2024-07-22 16:35:00
8	2500.00	4	t	4	t	2024-08-11 17:50:00
9	3000.00	2	f	3	f	2024-09-14 12:10:00
10	8000.00	6	t	5	t	2024-10-27 13:30:00
\.


--
-- Data for Name: prodejny; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prodejny (id_prodejny, adresa, jmeno_kontaktni_osoby, prijmeni_kontaktni_osoby, telefoni_cislo) FROM stdin;
1	Vaclavske namesti 1, Praha	Jan	Kolar	123456789
2	Namesti Svobody 10, Brno	Petr	Novak	987654321
3	Masarykova trida 5, Ostrava	Katerina	Vesela	456123789
4	Americka 20, Plzen	Martina	Dvorakova	789321456
5	Smetanova 3, Liberec	Jana	Kralova	321654987
\.


--
-- Data for Name: produkty; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.produkty (id_produktu, nazev, cena, pocet_kusu, id_hodnoceni) FROM stdin;
1	Notebook	15000.00	50	\N
2	Mobilni telefon	8000.00	100	\N
3	Televize	12000.00	30	\N
4	Tablet	5000.00	75	\N
5	Sluchatka	2000.00	150	\N
6	Klavesnice	1000.00	200	\N
7	Mys	500.00	250	\N
8	Monitor	4000.00	40	\N
9	Tiskarna	3000.00	60	\N
10	Fotoaparat	7000.00	20	\N
11	Kamera	9000.00	15	\N
12	Herni konzole	10000.00	25	\N
13	Reproduktor	1500.00	100	\N
14	Mikrofon	1200.00	80	\N
15	Projektor	8000.00	10	\N
17	Switch	3500.00	50	\N
18	USB disk	500.00	300	\N
19	Pametova karta	700.00	250	\N
20	Externi disk	2500.00	100	\N
16	Router	2500.00	0	\N
\.


--
-- Data for Name: produkty_objednavky; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.produkty_objednavky (id_produktu, id_objednavka, pocet_kusu) FROM stdin;
14	1	1
7	2	2
18	3	2
19	4	1
13	5	2
7	6	1
5	7	1
16	8	1
9	9	1
8	10	2
\.


--
-- Data for Name: reklamace; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reklamace (id_reklamace, id_produktu, id_zakaznika, duvod, datum_cas, id_prodejny) FROM stdin;
1	1	1	Neodpovídající kvalita	2024-01-21 10:00:00	1
2	2	2	Rozbité při doručení	2024-01-22 11:00:00	2
3	3	3	Nekompletní balení	2024-01-23 12:00:00	3
4	4	4	Zboží nefunguje	2024-01-24 13:00:00	4
5	5	5	Špatný výrobek	2024-01-25 14:00:00	5
6	6	6	Rozbitý displej	2024-01-26 15:00:00	1
7	7	7	Nefunkční klávesy	2024-01-27 16:00:00	2
8	8	8	Problém s napájením	2024-01-28 17:00:00	3
9	9	9	Nekompletní příslušenství	2024-01-29 18:00:00	4
10	10	10	Nefungující reproduktory	2024-01-30 19:00:00	5
11	11	11	Problém s připojením	2024-01-31 20:00:00	1
12	12	12	Poškrábaný povrch	2024-02-01 21:00:00	2
13	13	13	Vadný mikrofon	2024-02-02 22:00:00	3
14	14	14	Nekompletní kabeláž	2024-02-03 23:00:00	4
15	15	15	Neodpovídající popis	2024-02-04 09:00:00	5
16	16	16	Nekompatibilní s ostatními zařízeními	2024-02-05 08:00:00	1
17	17	17	Problém s ovladačem	2024-02-06 07:00:00	2
18	18	18	Nefunkční USB porty	2024-02-07 06:00:00	3
19	19	19	Vadný harddisk	2024-02-08 05:00:00	4
20	20	20	Nekompletní manuál	2024-02-09 04:00:00	5
\.


--
-- Data for Name: slevy_na_produkty; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.slevy_na_produkty (id_produktu, nazev, puvodni_cena, sleva_v_procentech, nova_cena) FROM stdin;
1	Notebook	15000.00	29.16	10626.00
2	Mobilni telefon	8000.00	5.21	7583.20
3	Televize	12000.00	7.01	11158.80
4	Tablet	5000.00	9.39	4530.50
5	Sluchatka	2000.00	15.35	1693.00
8	Monitor	4000.00	11.66	3533.60
9	Tiskarna	3000.00	10.12	2696.40
10	Fotoaparat	7000.00	25.32	5227.60
11	Kamera	9000.00	20.43	7161.30
12	Herni konzole	10000.00	24.79	7521.00
13	Reproduktor	1500.00	29.64	1055.40
14	Mikrofon	1200.00	7.23	1113.24
15	Projektor	8000.00	10.45	7164.00
16	Router	2500.00	6.74	2331.50
17	Switch	3500.00	15.08	2972.20
20	Externi disk	2500.00	6.21	2344.75
\.


--
-- Data for Name: zakaznici; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zakaznici (id_zakaznika, jmeno, prijmeni, email, heslo, adresa) FROM stdin;
1	Jan	Novak	jan.novak@example.com	password123	Praha
2	Petr	Svoboda	petr.svoboda@example.com	password123	Brno
3	Katerina	Dvorakova	katerina.dvorakova@example.com	password123	Ostrava
4	Martina	Havlova	martina.havlova@example.com	password123	Plzen
5	Jana	Pavlova	jana.pavlova@example.com	password123	Liberec
6	Josef	Kral	josef.kral@example.com	password123	Olomouc
7	Tereza	Blazkova	tereza.blazkova@example.com	password123	Ceske Budejovice
8	Simona	Vesela	simona.vesela@example.com	password123	Hradec Kralove
9	Alena	Urbanova	alena.urbanova@example.com	password123	Usti nad Labem
10	David	Novotny	david.novotny@example.com	password123	Pardubice
11	Eva	Mala	eva.mala@example.com	password123	Zlin
12	Michal	Pokorny	michal.pokorny@example.com	password123	Kladno
13	Lucie	Kohoutova	lucie.kohoutova@example.com	password123	Most
14	Pavla	Kralova	pavla.kralova@example.com	password123	Karvina
15	Milan	Horak	milan.horak@example.com	password123	Frydek-Mistek
16	Veronika	Jandova	veronika.jandova@example.com	password123	Opava
17	Martin	Sedlak	martin.sedlak@example.com	password123	Trinec
18	Lenka	Prochazkova	lenka.prochazkova@example.com	password123	Jihlava
19	Karel	Stepanek	karel.stepanek@example.com	password123	Teplice
20	Petr	Bartos	petr.bartos@example.com	password123	Decin
\.


--
-- Data for Name: zamestnanci; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zamestnanci (id_zamestnance, jmeno, prijmeni, id_pozice, id_prodejny, bankovni_ucet, id_nadrizeneho) FROM stdin;
10	David	Novotny	5	5	CZ6508000000192000146100	\N
15	Milan	Horak	5	5	CZ6508000000192000146600	\N
20	Petr	Bartos	5	5	CZ6508000000192000147100	\N
5	Jana	Vepřová	5	3	CZ6508000000192000145600	\N
4	Martina	Havlova	4	2	CZ6508000000192000145500	10
9	Alena	Urbanova	4	5	CZ6508000000192000146000	15
14	Pavla	Kralova	4	4	CZ6508000000192000146500	10
19	Karel	Stepanek	4	4	CZ6508000000192000147000	10
3	Katerina	Dvorakova	3	2	CZ6508000000192000145400	15
8	Simona	Vesela	3	4	CZ6508000000192000145900	5
13	Lucie	Kohoutova	3	3	CZ6508000000192000146400	5
18	Lenka	Prochazkova	3	3	CZ6508000000192000146900	20
2	Petr	Svoboda	2	1	CZ6508000000192000145300	15
7	Tereza	Blazkova	2	4	CZ6508000000192000145800	5
12	Michal	Pokorny	2	2	CZ6508000000192000146300	20
17	Martin	Sedlak	2	2	CZ6508000000192000146800	15
6	Josef	Kral	1	3	CZ6508000000192000145700	10
11	Eva	Mala	1	1	CZ6508000000192000146200	5
1	Jan	NovakTestZmeny	1	1	CZ6508000000192000145399	20
16	Veronika	NovéPříjmení	1	1	CZ6508000000192000146700	5
\.


--
-- Data for Name: zamestnanci_pozice; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zamestnanci_pozice (id_pozice, nazev) FROM stdin;
1	Pokladni
2	Prodavac
3	Vedouci prodejny
4	Skladnik
5	Manazer
\.


--
-- Name: dopravci_id_dopravce_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dopravci_id_dopravce_seq', 1, false);


--
-- Name: hodnoceni_id_hodnoceni_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.hodnoceni_id_hodnoceni_seq', 20, true);


--
-- Name: log_updates_id_log_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.log_updates_id_log_seq', 21, true);


--
-- Name: objednavky_id_objednavky_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.objednavky_id_objednavky_seq', 40, true);


--
-- Name: prodejny_id_prodejny_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prodejny_id_prodejny_seq', 5, true);


--
-- Name: produkty_id_produktu_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.produkty_id_produktu_seq', 20, true);


--
-- Name: reklamace_id_reklamace_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reklamace_id_reklamace_seq', 20, true);


--
-- Name: zakaznici_id_zakaznika_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zakaznici_id_zakaznika_seq', 20, true);


--
-- Name: zamestnanci_id_zamestnance_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zamestnanci_id_zamestnance_seq', 20, true);


--
-- Name: zamestnanci_pozice_id_pozice_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zamestnanci_pozice_id_pozice_seq', 5, true);


--
-- Name: dopravci dopravci_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dopravci
    ADD CONSTRAINT dopravci_pkey PRIMARY KEY (id_dopravce);


--
-- Name: hodnoceni hodnoceni_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hodnoceni
    ADD CONSTRAINT hodnoceni_pkey PRIMARY KEY (id_hodnoceni);


--
-- Name: log_updates log_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.log_updates
    ADD CONSTRAINT log_updates_pkey PRIMARY KEY (id_log);


--
-- Name: objednavky objednavky_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.objednavky
    ADD CONSTRAINT objednavky_pkey PRIMARY KEY (id_objednavky);


--
-- Name: prodejny prodejny_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prodejny
    ADD CONSTRAINT prodejny_pkey PRIMARY KEY (id_prodejny);


--
-- Name: produkty_objednavky produkty_objednavky_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.produkty_objednavky
    ADD CONSTRAINT produkty_objednavky_pkey PRIMARY KEY (id_produktu, id_objednavka);


--
-- Name: produkty produkty_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.produkty
    ADD CONSTRAINT produkty_pkey PRIMARY KEY (id_produktu);


--
-- Name: reklamace reklamace_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reklamace
    ADD CONSTRAINT reklamace_pkey PRIMARY KEY (id_reklamace);


--
-- Name: slevy_na_produkty slevy_na_produkty_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.slevy_na_produkty
    ADD CONSTRAINT slevy_na_produkty_pkey PRIMARY KEY (id_produktu);


--
-- Name: zakaznici zakaznici_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zakaznici
    ADD CONSTRAINT zakaznici_pkey PRIMARY KEY (id_zakaznika);


--
-- Name: zamestnanci zamestnanci_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zamestnanci
    ADD CONSTRAINT zamestnanci_pkey PRIMARY KEY (id_zamestnance);


--
-- Name: zamestnanci_pozice zamestnanci_pozice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zamestnanci_pozice
    ADD CONSTRAINT zamestnanci_pozice_pkey PRIMARY KEY (id_pozice);


--
-- Name: idx_fulltext_nazev; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fulltext_nazev ON public.produkty USING gin (to_tsvector('simple'::regconfig, (nazev)::text));


--
-- Name: idx_unique_bankovni_ucet; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unique_bankovni_ucet ON public.zamestnanci USING btree (bankovni_ucet);


--
-- Name: zamestnanci after_update_zamestnanci; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_update_zamestnanci AFTER UPDATE ON public.zamestnanci FOR EACH ROW EXECUTE FUNCTION public.log_update_function();


--
-- Name: hodnoceni hodnoceni_id_produktu_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hodnoceni
    ADD CONSTRAINT hodnoceni_id_produktu_fkey FOREIGN KEY (id_produktu) REFERENCES public.produkty(id_produktu);


--
-- Name: hodnoceni hodnoceni_id_zakaznika_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hodnoceni
    ADD CONSTRAINT hodnoceni_id_zakaznika_fkey FOREIGN KEY (id_zakaznika) REFERENCES public.zakaznici(id_zakaznika);


--
-- Name: objednavky objednavky_id_dopravce_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.objednavky
    ADD CONSTRAINT objednavky_id_dopravce_fkey FOREIGN KEY (id_dopravce) REFERENCES public.dopravci(id_dopravce);


--
-- Name: objednavky objednavky_id_zakaznika_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.objednavky
    ADD CONSTRAINT objednavky_id_zakaznika_fkey FOREIGN KEY (id_zakaznika) REFERENCES public.zakaznici(id_zakaznika);


--
-- Name: produkty produkty_id_hodnoceni_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.produkty
    ADD CONSTRAINT produkty_id_hodnoceni_fkey FOREIGN KEY (id_hodnoceni) REFERENCES public.hodnoceni(id_hodnoceni);


--
-- Name: produkty_objednavky produkty_objednavky_id_objednavka_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.produkty_objednavky
    ADD CONSTRAINT produkty_objednavky_id_objednavka_fkey FOREIGN KEY (id_objednavka) REFERENCES public.objednavky(id_objednavky);


--
-- Name: produkty_objednavky produkty_objednavky_id_produktu_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.produkty_objednavky
    ADD CONSTRAINT produkty_objednavky_id_produktu_fkey FOREIGN KEY (id_produktu) REFERENCES public.produkty(id_produktu);


--
-- Name: reklamace reklamace_id_prodejny_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reklamace
    ADD CONSTRAINT reklamace_id_prodejny_fkey FOREIGN KEY (id_prodejny) REFERENCES public.prodejny(id_prodejny);


--
-- Name: reklamace reklamace_id_produktu_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reklamace
    ADD CONSTRAINT reklamace_id_produktu_fkey FOREIGN KEY (id_produktu) REFERENCES public.produkty(id_produktu);


--
-- Name: reklamace reklamace_id_zakaznika_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reklamace
    ADD CONSTRAINT reklamace_id_zakaznika_fkey FOREIGN KEY (id_zakaznika) REFERENCES public.zakaznici(id_zakaznika);


--
-- Name: zamestnanci zamestnanci_id_pozice_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zamestnanci
    ADD CONSTRAINT zamestnanci_id_pozice_fkey FOREIGN KEY (id_pozice) REFERENCES public.zamestnanci_pozice(id_pozice);


--
-- Name: zamestnanci zamestnanci_id_prodejny_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zamestnanci
    ADD CONSTRAINT zamestnanci_id_prodejny_fkey FOREIGN KEY (id_prodejny) REFERENCES public.prodejny(id_prodejny);


--
-- Name: TABLE produkty; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE public.produkty TO ukazka;


--
-- PostgreSQL database dump complete
--

