--
-- NOTE:
--
-- File paths need to be edited. Search for $$PATH$$ and
-- replace it with the path to the directory containing
-- the extracted data files.
--
--
-- PostgreSQL database dump
--

-- Dumped from database version 11.3
-- Dumped by pg_dump version 11.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--DROP DATABASE jira_db;
--
-- Name: jira_db; Type: DATABASE; Schema: -; Owner: rahmanr
--

--CREATE DATABASE jira_db WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'English_United States.1252' LC_CTYPE = 'English_United States.1252';


--ALTER DATABASE jira_db OWNER TO rahmanr;

\connect jira_db

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

DROP schema sandpit_rahmanr cascade;

CREATE SCHEMA sandpit_rahmanr AUTHORIZATION rahmanr;

--
-- Name: mpaa_rating; Type: TYPE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TYPE sandpit_rahmanr.mpaa_rating AS ENUM (
    'G',
    'PG',
    'PG-13',
    'R',
    'NC-17'
);


ALTER TYPE sandpit_rahmanr.mpaa_rating OWNER TO rahmanr;

--
-- Name: year; Type: DOMAIN; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE DOMAIN sandpit_rahmanr.year AS integer
	CONSTRAINT year_check CHECK (((VALUE >= 1901) AND (VALUE <= 2155)));


ALTER DOMAIN sandpit_rahmanr.year OWNER TO rahmanr;

--
-- Name: _group_concat(text, text); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr._group_concat(text, text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT CASE
  WHEN $2 IS NULL THEN $1
  WHEN $1 IS NULL THEN $2
  ELSE $1 || ', ' || $2
END
$_$;


ALTER FUNCTION sandpit_rahmanr._group_concat(text, text) OWNER TO rahmanr;

--
-- Name: film_in_stock(integer, integer); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
     SELECT inventory_id
     FROM inventory
     WHERE film_id = $1
     AND store_id = $2
     AND inventory_in_stock(inventory_id);
$_$;


ALTER FUNCTION sandpit_rahmanr.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) OWNER TO rahmanr;

--
-- Name: film_not_in_stock(integer, integer); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
    SELECT inventory_id
    FROM inventory
    WHERE film_id = $1
    AND store_id = $2
    AND NOT inventory_in_stock(inventory_id);
$_$;


ALTER FUNCTION sandpit_rahmanr.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) OWNER TO rahmanr;

--
-- Name: get_customer_balance(integer, timestamp without time zone); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.get_customer_balance(p_customer_id integer, p_effective_date timestamp without time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
       --#OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
       --#THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
       --#   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
       --#   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
       --#   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
       --#   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED
DECLARE
    v_rentfees DECIMAL(5,2); --#FEES PAID TO RENT THE VIDEOS INITIALLY
    v_overfees INTEGER;      --#LATE FEES FOR PRIOR RENTALS
    v_payments DECIMAL(5,2); --#SUM OF PAYMENTS MADE PREVIOUSLY
BEGIN
    SELECT COALESCE(SUM(film.rental_rate),0) INTO v_rentfees
    FROM film, inventory, rental
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(IF((rental.return_date - rental.rental_date) > (film.rental_duration * '1 day'::interval),
        ((rental.return_date - rental.rental_date) - (film.rental_duration * '1 day'::interval)),0)),0) INTO v_overfees
    FROM rental, inventory, film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(payment.amount),0) INTO v_payments
    FROM payment
    WHERE payment.payment_date <= p_effective_date
    AND payment.customer_id = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END
$$;


ALTER FUNCTION sandpit_rahmanr.get_customer_balance(p_customer_id integer, p_effective_date timestamp without time zone) OWNER TO rahmanr;

--
-- Name: inventory_held_by_customer(integer); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.inventory_held_by_customer(p_inventory_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_customer_id INTEGER;
BEGIN

  SELECT customer_id INTO v_customer_id
  FROM rental
  WHERE return_date IS NULL
  AND inventory_id = p_inventory_id;

  RETURN v_customer_id;
END $$;


ALTER FUNCTION sandpit_rahmanr.inventory_held_by_customer(p_inventory_id integer) OWNER TO rahmanr;

--
-- Name: inventory_in_stock(integer); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.inventory_in_stock(p_inventory_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rentals INTEGER;
    v_out     INTEGER;
BEGIN
    -- AN ITEM IS IN-STOCK IF THERE ARE EITHER NO ROWS IN THE rental TABLE
    -- FOR THE ITEM OR ALL ROWS HAVE return_date POPULATED

    SELECT count(*) INTO v_rentals
    FROM rental
    WHERE inventory_id = p_inventory_id;

    IF v_rentals = 0 THEN
      RETURN TRUE;
    END IF;

    SELECT COUNT(rental_id) INTO v_out
    FROM inventory LEFT JOIN rental USING(inventory_id)
    WHERE inventory.inventory_id = p_inventory_id
    AND rental.return_date IS NULL;

    IF v_out > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
END $$;


ALTER FUNCTION sandpit_rahmanr.inventory_in_stock(p_inventory_id integer) OWNER TO rahmanr;

--
-- Name: last_day(timestamp without time zone); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.last_day(timestamp without time zone) RETURNS date
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN EXTRACT(MONTH FROM $1) = 12 THEN
      (((EXTRACT(YEAR FROM $1) + 1) operator(pg_catalog.||) '-01-01')::date - INTERVAL '1 day')::date
    ELSE
      ((EXTRACT(YEAR FROM $1) operator(pg_catalog.||) '-' operator(pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1) operator(pg_catalog.||) '-01')::date - INTERVAL '1 day')::date
    END
$_$;


ALTER FUNCTION sandpit_rahmanr.last_day(timestamp without time zone) OWNER TO rahmanr;

--
-- Name: last_updated(); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.last_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.last_update = CURRENT_TIMESTAMP;
    RETURN NEW;
END $$;


ALTER FUNCTION sandpit_rahmanr.last_updated() OWNER TO rahmanr;

--
-- Name: customer_customer_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.customer_customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.customer_customer_id_seq OWNER TO rahmanr;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: customer; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.customer (
    customer_id integer DEFAULT nextval('sandpit_rahmanr.customer_customer_id_seq'::regclass) NOT NULL,
    store_id smallint NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    email character varying(50),
    address_id smallint NOT NULL,
    activebool boolean DEFAULT true NOT NULL,
    create_date date DEFAULT ('now'::text)::date NOT NULL,
    last_update timestamp without time zone DEFAULT now(),
    active integer
);


ALTER TABLE sandpit_rahmanr.customer OWNER TO rahmanr;

--
-- Name: rewards_report(integer, numeric); Type: FUNCTION; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE FUNCTION sandpit_rahmanr.rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric) RETURNS SETOF sandpit_rahmanr.customer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
rr RECORD;
tmpSQL TEXT;
BEGIN

    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;

    last_month_start := CURRENT_DATE - '3 month'::interval;
    last_month_start := to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer (customer_id INTEGER NOT NULL PRIMARY KEY);

    /*
    Find all customers meeting the monthly purchase requirements
    */

    tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN '||quote_literal(last_month_start) ||' AND '|| quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > '|| min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' ||min_monthly_purchases ;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id' LOOP
        RETURN NEXT rr;
    END LOOP;

    /* Clean up */
    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

RETURN;
END
$_$;


ALTER FUNCTION sandpit_rahmanr.rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric) OWNER TO rahmanr;

--
-- Name: group_concat(text); Type: AGGREGATE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE AGGREGATE sandpit_rahmanr.group_concat(text) (
    SFUNC = sandpit_rahmanr._group_concat,
    STYPE = text
);


ALTER AGGREGATE sandpit_rahmanr.group_concat(text) OWNER TO rahmanr;

--
-- Name: actor_actor_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.actor_actor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.actor_actor_id_seq OWNER TO rahmanr;

--
-- Name: actor; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.actor (
    actor_id integer DEFAULT nextval('sandpit_rahmanr.actor_actor_id_seq'::regclass) NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.actor OWNER TO rahmanr;

--
-- Name: category_category_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.category_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.category_category_id_seq OWNER TO rahmanr;

--
-- Name: category; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.category (
    category_id integer DEFAULT nextval('sandpit_rahmanr.category_category_id_seq'::regclass) NOT NULL,
    name character varying(25) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.category OWNER TO rahmanr;

--
-- Name: film_film_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.film_film_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.film_film_id_seq OWNER TO rahmanr;

--
-- Name: film; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.film (
    film_id integer DEFAULT nextval('sandpit_rahmanr.film_film_id_seq'::regclass) NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    release_year sandpit_rahmanr.year,
    language_id smallint NOT NULL,
    rental_duration smallint DEFAULT 3 NOT NULL,
    rental_rate numeric(4,2) DEFAULT 4.99 NOT NULL,
    length smallint,
    replacement_cost numeric(5,2) DEFAULT 19.99 NOT NULL,
    rating sandpit_rahmanr.mpaa_rating DEFAULT 'G'::sandpit_rahmanr.mpaa_rating,
    last_update timestamp without time zone DEFAULT now() NOT NULL,
    special_features text[],
    fulltext tsvector NOT NULL
);


ALTER TABLE sandpit_rahmanr.film OWNER TO rahmanr;

--
-- Name: film_actor; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.film_actor (
    actor_id smallint NOT NULL,
    film_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.film_actor OWNER TO rahmanr;

--
-- Name: film_category; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.film_category (
    film_id smallint NOT NULL,
    category_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.film_category OWNER TO rahmanr;

--
-- Name: actor_info; Type: VIEW; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE VIEW sandpit_rahmanr.actor_info AS
 SELECT a.actor_id,
    a.first_name,
    a.last_name,
    sandpit_rahmanr.group_concat(DISTINCT (((c.name)::text || ': '::text) || ( SELECT sandpit_rahmanr.group_concat((f.title)::text) AS group_concat
           FROM ((sandpit_rahmanr.film f
             JOIN sandpit_rahmanr.film_category fc_1 ON ((f.film_id = fc_1.film_id)))
             JOIN sandpit_rahmanr.film_actor fa_1 ON ((f.film_id = fa_1.film_id)))
          WHERE ((fc_1.category_id = c.category_id) AND (fa_1.actor_id = a.actor_id))
          GROUP BY fa_1.actor_id))) AS film_info
   FROM (((sandpit_rahmanr.actor a
     LEFT JOIN sandpit_rahmanr.film_actor fa ON ((a.actor_id = fa.actor_id)))
     LEFT JOIN sandpit_rahmanr.film_category fc ON ((fa.film_id = fc.film_id)))
     LEFT JOIN sandpit_rahmanr.category c ON ((fc.category_id = c.category_id)))
  GROUP BY a.actor_id, a.first_name, a.last_name;


ALTER TABLE sandpit_rahmanr.actor_info OWNER TO rahmanr;

--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.address_address_id_seq OWNER TO rahmanr;

--
-- Name: address; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.address (
    address_id integer DEFAULT nextval('sandpit_rahmanr.address_address_id_seq'::regclass) NOT NULL,
    address character varying(50) NOT NULL,
    address2 character varying(50),
    district character varying(20) NOT NULL,
    city_id smallint NOT NULL,
    postal_code character varying(10),
    phone character varying(20) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.address OWNER TO rahmanr;

--
-- Name: city_city_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.city_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.city_city_id_seq OWNER TO rahmanr;

--
-- Name: city; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.city (
    city_id integer DEFAULT nextval('sandpit_rahmanr.city_city_id_seq'::regclass) NOT NULL,
    city character varying(50) NOT NULL,
    country_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.city OWNER TO rahmanr;

--
-- Name: country_country_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.country_country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.country_country_id_seq OWNER TO rahmanr;

--
-- Name: country; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.country (
    country_id integer DEFAULT nextval('sandpit_rahmanr.country_country_id_seq'::regclass) NOT NULL,
    country character varying(50) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.country OWNER TO rahmanr;

--
-- Name: customer_list; Type: VIEW; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE VIEW sandpit_rahmanr.customer_list AS
 SELECT cu.customer_id AS id,
    (((cu.first_name)::text || ' '::text) || (cu.last_name)::text) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
        CASE
            WHEN cu.activebool THEN 'active'::text
            ELSE ''::text
        END AS notes,
    cu.store_id AS sid
   FROM (((sandpit_rahmanr.customer cu
     JOIN sandpit_rahmanr.address a ON ((cu.address_id = a.address_id)))
     JOIN sandpit_rahmanr.city ON ((a.city_id = city.city_id)))
     JOIN sandpit_rahmanr.country ON ((city.country_id = country.country_id)));


ALTER TABLE sandpit_rahmanr.customer_list OWNER TO rahmanr;

--
-- Name: film_list; Type: VIEW; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE VIEW sandpit_rahmanr.film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    sandpit_rahmanr.group_concat((((actor.first_name)::text || ' '::text) || (actor.last_name)::text)) AS actors
   FROM ((((sandpit_rahmanr.category
     LEFT JOIN sandpit_rahmanr.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN sandpit_rahmanr.film ON ((film_category.film_id = film.film_id)))
     JOIN sandpit_rahmanr.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN sandpit_rahmanr.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


ALTER TABLE sandpit_rahmanr.film_list OWNER TO rahmanr;

--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.inventory_inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.inventory_inventory_id_seq OWNER TO rahmanr;

--
-- Name: inventory; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.inventory (
    inventory_id integer DEFAULT nextval('sandpit_rahmanr.inventory_inventory_id_seq'::regclass) NOT NULL,
    film_id smallint NOT NULL,
    store_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.inventory OWNER TO rahmanr;

--
-- Name: language_language_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.language_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.language_language_id_seq OWNER TO rahmanr;

--
-- Name: language; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.language (
    language_id integer DEFAULT nextval('sandpit_rahmanr.language_language_id_seq'::regclass) NOT NULL,
    name character(20) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.language OWNER TO rahmanr;

--
-- Name: nicer_but_slower_film_list; Type: VIEW; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE VIEW sandpit_rahmanr.nicer_but_slower_film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    sandpit_rahmanr.group_concat((((upper("substring"((actor.first_name)::text, 1, 1)) || lower("substring"((actor.first_name)::text, 2))) || upper("substring"((actor.last_name)::text, 1, 1))) || lower("substring"((actor.last_name)::text, 2)))) AS actors
   FROM ((((sandpit_rahmanr.category
     LEFT JOIN sandpit_rahmanr.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN sandpit_rahmanr.film ON ((film_category.film_id = film.film_id)))
     JOIN sandpit_rahmanr.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN sandpit_rahmanr.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


ALTER TABLE sandpit_rahmanr.nicer_but_slower_film_list OWNER TO rahmanr;

--
-- Name: payment_payment_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.payment_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.payment_payment_id_seq OWNER TO rahmanr;

--
-- Name: payment; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.payment (
    payment_id integer DEFAULT nextval('sandpit_rahmanr.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id smallint NOT NULL,
    staff_id smallint NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp without time zone NOT NULL
);


ALTER TABLE sandpit_rahmanr.payment OWNER TO rahmanr;

--
-- Name: rental_rental_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.rental_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.rental_rental_id_seq OWNER TO rahmanr;

--
-- Name: rental; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.rental (
    rental_id integer DEFAULT nextval('sandpit_rahmanr.rental_rental_id_seq'::regclass) NOT NULL,
    rental_date timestamp without time zone NOT NULL,
    inventory_id integer NOT NULL,
    customer_id smallint NOT NULL,
    return_date timestamp without time zone,
    staff_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.rental OWNER TO rahmanr;

--
-- Name: sales_by_film_category; Type: VIEW; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE VIEW sandpit_rahmanr.sales_by_film_category AS
 SELECT c.name AS category,
    sum(p.amount) AS total_sales
   FROM (((((sandpit_rahmanr.payment p
     JOIN sandpit_rahmanr.rental r ON ((p.rental_id = r.rental_id)))
     JOIN sandpit_rahmanr.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN sandpit_rahmanr.film f ON ((i.film_id = f.film_id)))
     JOIN sandpit_rahmanr.film_category fc ON ((f.film_id = fc.film_id)))
     JOIN sandpit_rahmanr.category c ON ((fc.category_id = c.category_id)))
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC;


ALTER TABLE sandpit_rahmanr.sales_by_film_category OWNER TO rahmanr;

--
-- Name: staff_staff_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.staff_staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.staff_staff_id_seq OWNER TO rahmanr;

--
-- Name: staff; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.staff (
    staff_id integer DEFAULT nextval('sandpit_rahmanr.staff_staff_id_seq'::regclass) NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    address_id smallint NOT NULL,
    email character varying(50),
    store_id smallint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    username character varying(16) NOT NULL,
    password character varying(40),
    last_update timestamp without time zone DEFAULT now() NOT NULL,
    picture bytea
);


ALTER TABLE sandpit_rahmanr.staff OWNER TO rahmanr;

--
-- Name: store_store_id_seq; Type: SEQUENCE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE SEQUENCE sandpit_rahmanr.store_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sandpit_rahmanr.store_store_id_seq OWNER TO rahmanr;

--
-- Name: store; Type: TABLE; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TABLE sandpit_rahmanr.store (
    store_id integer DEFAULT nextval('sandpit_rahmanr.store_store_id_seq'::regclass) NOT NULL,
    manager_staff_id smallint NOT NULL,
    address_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sandpit_rahmanr.store OWNER TO rahmanr;

--
-- Name: sales_by_store; Type: VIEW; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE VIEW sandpit_rahmanr.sales_by_store AS
 SELECT (((c.city)::text || ','::text) || (cy.country)::text) AS store,
    (((m.first_name)::text || ' '::text) || (m.last_name)::text) AS manager,
    sum(p.amount) AS total_sales
   FROM (((((((sandpit_rahmanr.payment p
     JOIN sandpit_rahmanr.rental r ON ((p.rental_id = r.rental_id)))
     JOIN sandpit_rahmanr.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN sandpit_rahmanr.store s ON ((i.store_id = s.store_id)))
     JOIN sandpit_rahmanr.address a ON ((s.address_id = a.address_id)))
     JOIN sandpit_rahmanr.city c ON ((a.city_id = c.city_id)))
     JOIN sandpit_rahmanr.country cy ON ((c.country_id = cy.country_id)))
     JOIN sandpit_rahmanr.staff m ON ((s.manager_staff_id = m.staff_id)))
  GROUP BY cy.country, c.city, s.store_id, m.first_name, m.last_name
  ORDER BY cy.country, c.city;


ALTER TABLE sandpit_rahmanr.sales_by_store OWNER TO rahmanr;

--
-- Name: staff_list; Type: VIEW; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE VIEW sandpit_rahmanr.staff_list AS
 SELECT s.staff_id AS id,
    (((s.first_name)::text || ' '::text) || (s.last_name)::text) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
    s.store_id AS sid
   FROM (((sandpit_rahmanr.staff s
     JOIN sandpit_rahmanr.address a ON ((s.address_id = a.address_id)))
     JOIN sandpit_rahmanr.city ON ((a.city_id = city.city_id)))
     JOIN sandpit_rahmanr.country ON ((city.country_id = country.country_id)));


ALTER TABLE sandpit_rahmanr.staff_list OWNER TO rahmanr;

--
-- Data for Name: actor; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.actor (actor_id, first_name, last_name, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.actor (actor_id, first_name, last_name, last_update) FROM '/tmp/mozilla_riz0/3057.dat';

--
-- Data for Name: address; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.address (address_id, address, address2, district, city_id, postal_code, phone, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.address (address_id, address, address2, district, city_id, postal_code, phone, last_update) FROM '/tmp/mozilla_riz0/3065.dat';

--
-- Data for Name: category; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.category (category_id, name, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.category (category_id, name, last_update) FROM '/tmp/mozilla_riz0/3059.dat';

--
-- Data for Name: city; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.city (city_id, city, country_id, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.city (city_id, city, country_id, last_update) FROM '/tmp/mozilla_riz0/3067.dat';

--
-- Data for Name: country; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.country (country_id, country, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.country (country_id, country, last_update) FROM '/tmp/mozilla_riz0/3069.dat';

--
-- Data for Name: customer; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.customer (customer_id, store_id, first_name, last_name, email, address_id, activebool, create_date, last_update, active) FROM stdin;
\.
COPY sandpit_rahmanr.customer (customer_id, store_id, first_name, last_name, email, address_id, activebool, create_date, last_update, active) FROM '/tmp/mozilla_riz0/3055.dat';

--
-- Data for Name: film; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.film (film_id, title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features, fulltext) FROM stdin;
\.
COPY sandpit_rahmanr.film (film_id, title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features, fulltext) FROM '/tmp/mozilla_riz0/3061.dat';

--
-- Data for Name: film_actor; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.film_actor (actor_id, film_id, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.film_actor (actor_id, film_id, last_update) FROM '/tmp/mozilla_riz0/3062.dat';

--
-- Data for Name: film_category; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.film_category (film_id, category_id, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.film_category (film_id, category_id, last_update) FROM '/tmp/mozilla_riz0/3063.dat';

--
-- Data for Name: inventory; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.inventory (inventory_id, film_id, store_id, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.inventory (inventory_id, film_id, store_id, last_update) FROM '/tmp/mozilla_riz0/3071.dat';

--
-- Data for Name: language; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.language (language_id, name, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.language (language_id, name, last_update) FROM '/tmp/mozilla_riz0/3073.dat';

--
-- Data for Name: payment; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.payment (payment_id, customer_id, staff_id, rental_id, amount, payment_date) FROM stdin;
\.
COPY sandpit_rahmanr.payment (payment_id, customer_id, staff_id, rental_id, amount, payment_date) FROM '/tmp/mozilla_riz0/3075.dat';

--
-- Data for Name: rental; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update) FROM '/tmp/mozilla_riz0/3077.dat';

--
-- Data for Name: staff; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.staff (staff_id, first_name, last_name, address_id, email, store_id, active, username, password, last_update, picture) FROM stdin;
\.
COPY sandpit_rahmanr.staff (staff_id, first_name, last_name, address_id, email, store_id, active, username, password, last_update, picture) FROM '/tmp/mozilla_riz0/3079.dat';

--
-- Data for Name: store; Type: TABLE DATA; Schema: sandpit_rahmanr. Owner: rahmanr
--

COPY sandpit_rahmanr.store (store_id, manager_staff_id, address_id, last_update) FROM stdin;
\.
COPY sandpit_rahmanr.store (store_id, manager_staff_id, address_id, last_update) FROM '/tmp/mozilla_riz0/3081.dat';

--
-- Name: actor_actor_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.actor_actor_id_seq', 200, true);


--
-- Name: address_address_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.address_address_id_seq', 605, true);


--
-- Name: category_category_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.category_category_id_seq', 16, true);


--
-- Name: city_city_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.city_city_id_seq', 600, true);


--
-- Name: country_country_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.country_country_id_seq', 109, true);


--
-- Name: customer_customer_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.customer_customer_id_seq', 599, true);


--
-- Name: film_film_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.film_film_id_seq', 1000, true);


--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.inventory_inventory_id_seq', 4581, true);


--
-- Name: language_language_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.language_language_id_seq', 6, true);


--
-- Name: payment_payment_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.payment_payment_id_seq', 32098, true);


--
-- Name: rental_rental_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.rental_rental_id_seq', 16049, true);


--
-- Name: staff_staff_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.staff_staff_id_seq', 2, true);


--
-- Name: store_store_id_seq; Type: SEQUENCE SET; Schema: sandpit_rahmanr. Owner: rahmanr
--

SELECT pg_catalog.setval('sandpit_rahmanr.store_store_id_seq', 2, true);


--
-- Name: actor actor_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.actor
    ADD CONSTRAINT actor_pkey PRIMARY KEY (actor_id);


--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);


--
-- Name: city city_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.city
    ADD CONSTRAINT city_pkey PRIMARY KEY (city_id);


--
-- Name: country country_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.country
    ADD CONSTRAINT country_pkey PRIMARY KEY (country_id);


--
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);


--
-- Name: film_actor film_actor_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film_actor
    ADD CONSTRAINT film_actor_pkey PRIMARY KEY (actor_id, film_id);


--
-- Name: film_category film_category_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film_category
    ADD CONSTRAINT film_category_pkey PRIMARY KEY (film_id, category_id);


--
-- Name: film film_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film
    ADD CONSTRAINT film_pkey PRIMARY KEY (film_id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);


--
-- Name: language language_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (language_id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- Name: rental rental_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.rental
    ADD CONSTRAINT rental_pkey PRIMARY KEY (rental_id);


--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);


--
-- Name: store store_pkey; Type: CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (store_id);


--
-- Name: film_fulltext_idx; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX film_fulltext_idx ON sandpit_rahmanr.film USING gist (fulltext);


--
-- Name: idx_actor_last_name; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_actor_last_name ON sandpit_rahmanr.actor USING btree (last_name);


--
-- Name: idx_fk_address_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_address_id ON sandpit_rahmanr.customer USING btree (address_id);


--
-- Name: idx_fk_city_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_city_id ON sandpit_rahmanr.address USING btree (city_id);


--
-- Name: idx_fk_country_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_country_id ON sandpit_rahmanr.city USING btree (country_id);


--
-- Name: idx_fk_customer_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_customer_id ON sandpit_rahmanr.payment USING btree (customer_id);


--
-- Name: idx_fk_film_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_film_id ON sandpit_rahmanr.film_actor USING btree (film_id);


--
-- Name: idx_fk_inventory_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_inventory_id ON sandpit_rahmanr.rental USING btree (inventory_id);


--
-- Name: idx_fk_language_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_language_id ON sandpit_rahmanr.film USING btree (language_id);


--
-- Name: idx_fk_rental_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_rental_id ON sandpit_rahmanr.payment USING btree (rental_id);


--
-- Name: idx_fk_staff_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_staff_id ON sandpit_rahmanr.payment USING btree (staff_id);


--
-- Name: idx_fk_store_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_fk_store_id ON sandpit_rahmanr.customer USING btree (store_id);


--
-- Name: idx_last_name; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_last_name ON sandpit_rahmanr.customer USING btree (last_name);


--
-- Name: idx_store_id_film_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_store_id_film_id ON sandpit_rahmanr.inventory USING btree (store_id, film_id);


--
-- Name: idx_title; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE INDEX idx_title ON sandpit_rahmanr.film USING btree (title);


--
-- Name: idx_unq_manager_staff_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE UNIQUE INDEX idx_unq_manager_staff_id ON sandpit_rahmanr.store USING btree (manager_staff_id);


--
-- Name: idx_unq_rental_rental_date_inventory_id_customer_id; Type: INDEX; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE UNIQUE INDEX idx_unq_rental_rental_date_inventory_id_customer_id ON sandpit_rahmanr.rental USING btree (rental_date, inventory_id, customer_id);


--
-- Name: film film_fulltext_trigger; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER film_fulltext_trigger BEFORE INSERT OR UPDATE ON sandpit_rahmanr.film FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('fulltext', 'pg_catalog.english', 'title', 'description');


--
-- Name: actor last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.actor FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: address last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.address FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: category last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.category FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: city last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.city FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: country last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.country FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: customer last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.customer FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: film last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.film FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: film_actor last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.film_actor FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: film_category last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.film_category FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: inventory last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.inventory FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: language last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.language FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: rental last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.rental FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: staff last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.staff FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: store last_updated; Type: TRIGGER; Schema: sandpit_rahmanr. Owner: rahmanr
--

CREATE TRIGGER last_updated BEFORE UPDATE ON sandpit_rahmanr.store FOR EACH ROW EXECUTE PROCEDURE sandpit_rahmanr.last_updated();


--
-- Name: customer customer_address_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.customer
    ADD CONSTRAINT customer_address_id_fkey FOREIGN KEY (address_id) REFERENCES sandpit_rahmanr.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_actor film_actor_actor_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film_actor
    ADD CONSTRAINT film_actor_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES sandpit_rahmanr.actor(actor_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_actor film_actor_film_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film_actor
    ADD CONSTRAINT film_actor_film_id_fkey FOREIGN KEY (film_id) REFERENCES sandpit_rahmanr.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_category film_category_category_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film_category
    ADD CONSTRAINT film_category_category_id_fkey FOREIGN KEY (category_id) REFERENCES sandpit_rahmanr.category(category_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_category film_category_film_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film_category
    ADD CONSTRAINT film_category_film_id_fkey FOREIGN KEY (film_id) REFERENCES sandpit_rahmanr.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film film_language_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.film
    ADD CONSTRAINT film_language_id_fkey FOREIGN KEY (language_id) REFERENCES sandpit_rahmanr.language(language_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: address fk_address_city; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.address
    ADD CONSTRAINT fk_address_city FOREIGN KEY (city_id) REFERENCES sandpit_rahmanr.city(city_id);


--
-- Name: city fk_city; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.city
    ADD CONSTRAINT fk_city FOREIGN KEY (country_id) REFERENCES sandpit_rahmanr.country(country_id);


--
-- Name: inventory inventory_film_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.inventory
    ADD CONSTRAINT inventory_film_id_fkey FOREIGN KEY (film_id) REFERENCES sandpit_rahmanr.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: payment payment_customer_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.payment
    ADD CONSTRAINT payment_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES sandpit_rahmanr.customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: payment payment_rental_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.payment
    ADD CONSTRAINT payment_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES sandpit_rahmanr.rental(rental_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: payment payment_staff_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.payment
    ADD CONSTRAINT payment_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES sandpit_rahmanr.staff(staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental rental_customer_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.rental
    ADD CONSTRAINT rental_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES sandpit_rahmanr.customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental rental_inventory_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.rental
    ADD CONSTRAINT rental_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES sandpit_rahmanr.inventory(inventory_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental rental_staff_id_key; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.rental
    ADD CONSTRAINT rental_staff_id_key FOREIGN KEY (staff_id) REFERENCES sandpit_rahmanr.staff(staff_id);


--
-- Name: staff staff_address_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.staff
    ADD CONSTRAINT staff_address_id_fkey FOREIGN KEY (address_id) REFERENCES sandpit_rahmanr.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: store store_address_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.store
    ADD CONSTRAINT store_address_id_fkey FOREIGN KEY (address_id) REFERENCES sandpit_rahmanr.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: store store_manager_staff_id_fkey; Type: FK CONSTRAINT; Schema: sandpit_rahmanr. Owner: rahmanr
--

ALTER TABLE ONLY sandpit_rahmanr.store
    ADD CONSTRAINT store_manager_staff_id_fkey FOREIGN KEY (manager_staff_id) REFERENCES sandpit_rahmanr.staff(staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

