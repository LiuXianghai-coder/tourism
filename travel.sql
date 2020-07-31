--
-- PostgreSQL database dump
--

-- Dumped from database version 12.1
-- Dumped by pg_dump version 12.1

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
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: travel_simple_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.travel_simple_type AS (
	id character varying(30),
	title text,
	score double precision,
	price double precision,
	visit_num integer,
	start_date date,
	kind character varying(10),
	imageaddress text
);


ALTER TYPE public.travel_simple_type OWNER TO postgres;

--
-- Name: auto_increase_star(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auto_increase_star() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        UPDATE raider SET stars = stars + 1 WHERE raider.raider_id = new.raider_id;
        RAISE NOTICE '%', new.raider_id;
        RETURN new;
    end
$$;


ALTER FUNCTION public.auto_increase_star() OWNER TO postgres;

--
-- Name: delete_raider(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_raider() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM raider_kind WHERE raider_id = old.raider_id;
    DELETE FROM user_save_raider WHERE raider_id = old.raider_id;
    DELETE FROM raider_comment WHERE raider_id = old.raider_id;
    DELETE FROM travel_raider WHERE raider_id = old.raider_id;
    DELETE FROM raider_detail WHERE raider_id=old.raider_id;
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_raider() OWNER TO postgres;

--
-- Name: delete_travel_product(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_travel_product() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        DELETE FROM travel_kind WHERE travel_id=OLD.travel_id;
        DELETE FROM user_travel_boking WHERE travel_id=OLD.travel_id;
        DELETE FROM travel_image WHERE travel_id=OLD.travel_id;
        DELETE FROM travel_stoke WHERE travel_id=OLD.travel_id;
        DELETE FROM travel_raider WHERE travel_id=OLD.travel_id;
        RETURN OLD;
    END;
$$;


ALTER FUNCTION public.delete_travel_product() OWNER TO postgres;

--
-- Name: delete_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
       DELETE FROM user_image WHERE user_id=OLD.user_id;
       DELETE FROM raider_comment WHERE user_id=OLD.user_id;
       DELETE FROM user_raider WHERE user_id=OLD.user_id;
       DELETE FROM user_save_raider WHERE user_id = OLD.user_id;
       DELETE FROM user_star_raider WHERE user_id=OLD.user_id;
       DELETE FROM user_travel_save WHERE user_id=OLD.user_id;
       DELETE FROM user_travel_booking WHERE user_id=OLD.user_id;

       RETURN OLD;
    END;
$$;


ALTER FUNCTION public.delete_user() OWNER TO postgres;

--
-- Name: find_search_raider(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_search_raider(keyword text) RETURNS TABLE(id character varying, title text, stars integer, visits integer, raider_cal date, date_diff bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM update_date_between();
    DROP TABLE IF EXISTS raider_search_temp;
    CREATE TEMP TABLE raider_search_temp AS
    SELECT temp.raider_id,
           temp.raider_title,
           temp.stars,
           temp.visits,
           temp.raider_date,
           temp.date_between,
           kind_name
    FROM (SELECT raider.*, raider_kind.kind_id
          FROM raider
                   JOIN raider_kind ON raider.raider_id = raider_kind.raider_id)
             AS temp
             JOIN raider_kind_instance ON temp.kind_id = raider_kind_instance.kind_id
    WHERE raider_title LIKE concat('%', keyWord, '%')
       OR kind_name LIKE concat('%', keyWord, '%');

    DROP index IF EXISTS raider_searchTemp_index;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE INDEX ON raider_search_temp USING gin (raider_title gin_trgm_ops, kind_name gin_trgm_ops);

    RETURN QUERY SELECT raider_search_temp.raider_id,
                        raider_search_temp.raider_title,
                        raider_search_temp.stars,
                        raider_search_temp.visits,
                        raider_search_temp.raider_date,
                        raider_search_temp.date_between
                 FROM raider_search_temp;
END;
$$;


ALTER FUNCTION public.find_search_raider(keyword text) OWNER TO postgres;

--
-- Name: find_search_travel(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_search_travel(keyword text) RETURNS TABLE(id character varying, title text, score double precision, visit_num integer, price double precision, kind character varying, travel_date date, imageaddress text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DROP TABLE IF EXISTS travel_search_temp;
    CREATE TEMP TABLE travel_search_temp AS
    WITH cte AS
             (
                 SELECT travel_search_result.*,
                        travel_image.image_address AS imageAddress,
                        ROW_NUMBER() OVER (PARTITION BY travel_search_result.id
                            ORDER BY image_address DESC) AS rn
                 FROM (SELECT travel_temp.*
                       FROM (SELECT search_result.travel_id        AS id,
                                    search_result.travel_title     AS title,
                                    search_result.travel_score     AS score,
                                    search_result.num_people       AS visit_num,
                                    search_result.travel_price     AS price,
                                    search_result.travel_date      AS travel_date,
                                    travel_kind_instance.kind_name AS kind
                             FROM (SELECT travel_product.travel_id,
                                          travel_product.travel_title,
                                          travel_product.travel_score,
                                          travel_product.num_people,
                                          travel_product.travel_price,
                                          travel_product.travel_date,
                                          travel_kind.kind_id
                                   FROM travel_product
                                            JOIN travel_kind ON travel_product.travel_id = travel_kind.travel_id)
                                      AS search_result
                                      JOIN travel_kind_instance
                                           ON search_result.kind_id = travel_kind_instance.kind_id
                             WHERE search_result.travel_title LIKE CONCAT('%', keyWord, '%')
                                OR travel_kind_instance.kind_name LIKE CONCAT('%', keyWord, '%')) AS travel_temp)
                          AS travel_search_result
                          JOIN travel_image ON travel_search_result.id = travel_image.travel_id
             )
    SELECT cte.id,
           cte.title,
           cte.score,
           cte.visit_num,
           cte.price,
           cte.kind,
           cte.travel_date,
           cte.imageAddress
    FROM cte
    WHERE rn = 1;

    DROP INDEX IF EXISTS travel_search_gin_index;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE INDEX travel_search_gin_index ON travel_search_temp USING gin (title gin_trgm_ops, kind gin_trgm_ops);

    RETURN QUERY SELECT * FROM travel_search_temp;
END ;
$$;


ALTER FUNCTION public.find_search_travel(keyword text) OWNER TO postgres;

--
-- Name: get_travel_first_image(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_travel_first_image() RETURNS TABLE(id character varying, title text, score double precision, price double precision, visit_num integer, start_date date, kind character varying, imageaddress text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    travelId              VARCHAR(30);
    DECLARE result_record travel_image_type;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS travel_first_image_temp
    (
        id           VARCHAR(30) PRIMARY KEY,
        title        text NOT NULL,
        score        FLOAT DEFAULT 0.0,
        price        FLOAT DEFAULT 0.0,
        visit_num    INT   DEFAULT 0,
        start_date   date,
        kind         VARCHAR(10),
        imageAddress text NOT NULL
    );
    CREATE INDEX ON travel_first_image_temp (id);
    DELETE FROM travel_first_image_temp WHERE true;
    FOR travelId IN SELECT travel_id FROM travel_product
        LOOP
            SELECT travel_id, travel_title, travel_score, travel_price, num_people, travel_date
            INTO result_record.id, result_record.title, result_record.score,
                result_record.price, result_record.visit_num, result_record.start_date
            FROM travel_product
            WHERE travel_id = travelId;

            SELECT kind_name
            INTO result_record.kind
            FROM (SELECT *
                  FROM (SELECT travel_product.*, travel_kind.kind_id
                        FROM travel_product
                                 JOIN travel_kind
                                      ON travel_product.travel_id = travel_kind.travel_id) AS temp
                           JOIN
                       travel_kind_instance ON temp.kind_id = travel_kind_instance.kind_id
                 ) AS kind_table
            WHERE travel_id = travelId;

            SELECT image_address
            INTO result_record.imageAddress
            FROM travel_image
            WHERE travel_id = travelId
            LIMIT 1;

            INSERT INTO travel_first_image_temp
            VALUES (result_record.id, result_record.title, result_record.score,
                    result_record.price, result_record.visit_num, result_record.start_date,
                    result_record.kind, result_record.imageaddress)
            ON CONFLICT DO NOTHING;
        end loop;
    RETURN QUERY SELECT * FROM travel_first_image_temp;
END;
$$;


ALTER FUNCTION public.get_travel_first_image() OWNER TO postgres;

--
-- Name: get_travel_simple(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_travel_simple() RETURNS TABLE(id character varying, title text, score double precision, price double precision, visit_num integer, start_date date, kind character varying, imageaddress text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    travelId              VARCHAR(30);
    DECLARE result_record travel_simple_type;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS travel_simple_temp
    (
        id           VARCHAR(30) PRIMARY KEY,
        title        text NOT NULL,
        score        FLOAT DEFAULT 0.0,
        price        FLOAT DEFAULT 0.0,
        visit_num    INT   DEFAULT 0,
        start_date   date,
        kind         VARCHAR(10),
        imageAddress text NOT NULL
    );
    CREATE INDEX ON travel_simple_temp (id);
    DELETE FROM travel_simple_temp WHERE true;
    FOR travelId IN SELECT travel_id FROM travel_product
        LOOP
            SELECT travel_id, travel_title, travel_score, travel_price, num_people, travel_date
            INTO result_record.id, result_record.title, result_record.score,
                result_record.price, result_record.visit_num, result_record.start_date
            FROM travel_product
            WHERE travel_id = travelId;

            SELECT kind_name
            INTO result_record.kind
            FROM (SELECT *
                  FROM ((SELECT travel_product.*, travel_kind.kind_id
                         FROM travel_product
                                  JOIN travel_kind
                                       ON travel_product.travel_id = travel_kind.travel_id) AS temp
                           JOIN
                       travel_kind_instance ON temp.kind_id = travel_kind_instance.kind_id
                           )) AS kind_table
            WHERE travel_id = travelId;

            SELECT image_address
            INTO result_record.imageAddress
            FROM travel_image
            WHERE travel_id = travelId
            LIMIT 1;

            INSERT INTO travel_simple_temp(id, title, score, price, visit_num, start_date, kind, imageAddress)
            VALUES (result_record.id, result_record.title, result_record.score,
                    result_record.price, result_record.visit_num, result_record.start_date,
                    result_record.kind, result_record.imageaddress)
            ON CONFLICT DO NOTHING;
        end loop;
    RETURN QUERY SELECT * FROM travel_simple_temp;
END;
$$;


ALTER FUNCTION public.get_travel_simple() OWNER TO postgres;

--
-- Name: update_date_between(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_date_between() RETURNS TABLE(id character varying, title text, stars integer, visits integer, raidercal date, date_diff bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE raider
    SET date_between =
            date_part('day', cast(now() as TIMESTAMP) - cast(raider_date as TIMESTAMP))
    WHERE true;

    RETURN QUERY SELECT * FROM raider;
end;
$$;


ALTER FUNCTION public.update_date_between() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: raider; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raider (
    raider_id character varying(30) NOT NULL,
    raider_title text NOT NULL,
    stars integer DEFAULT 0,
    visits integer DEFAULT 0,
    raider_date date,
    date_between bigint
);


ALTER TABLE public.raider OWNER TO postgres;

--
-- Name: raider_comment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raider_comment (
    user_id character varying(254) NOT NULL,
    raider_id character varying(30) NOT NULL,
    comment_id integer NOT NULL,
    comment_content text NOT NULL,
    comment_date date
);


ALTER TABLE public.raider_comment OWNER TO postgres;

--
-- Name: raider_comment_comment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.raider_comment_comment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.raider_comment_comment_id_seq OWNER TO postgres;

--
-- Name: raider_comment_comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.raider_comment_comment_id_seq OWNED BY public.raider_comment.comment_id;


--
-- Name: raider_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raider_detail (
    raider_id character varying(30) NOT NULL,
    raider_step integer NOT NULL,
    font_size smallint NOT NULL,
    raider_detail text NOT NULL
);


ALTER TABLE public.raider_detail OWNER TO postgres;

--
-- Name: raider_kind; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raider_kind (
    raider_id character varying(30) NOT NULL,
    kind_id integer NOT NULL
);


ALTER TABLE public.raider_kind OWNER TO postgres;

--
-- Name: raider_kind_instance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raider_kind_instance (
    kind_id integer NOT NULL,
    kind_name character varying(10)
);


ALTER TABLE public.raider_kind_instance OWNER TO postgres;

--
-- Name: raider_kind_instance_kind_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.raider_kind_instance_kind_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.raider_kind_instance_kind_id_seq OWNER TO postgres;

--
-- Name: raider_kind_instance_kind_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.raider_kind_instance_kind_id_seq OWNED BY public.raider_kind_instance.kind_id;


--
-- Name: raider_stars_req; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.raider_stars_req
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.raider_stars_req OWNER TO postgres;

--
-- Name: travel_image; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.travel_image (
    travel_id character varying(30) NOT NULL,
    image_address text NOT NULL
);


ALTER TABLE public.travel_image OWNER TO postgres;

--
-- Name: travel_kind; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.travel_kind (
    travel_id character varying(30) NOT NULL,
    kind_id integer NOT NULL
);


ALTER TABLE public.travel_kind OWNER TO postgres;

--
-- Name: travel_kind_instance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.travel_kind_instance (
    kind_id smallint NOT NULL,
    kind_name character varying(10)
);


ALTER TABLE public.travel_kind_instance OWNER TO postgres;

--
-- Name: travel_kind_instance_kind_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.travel_kind_instance_kind_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.travel_kind_instance_kind_id_seq OWNER TO postgres;

--
-- Name: travel_kind_instance_kind_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.travel_kind_instance_kind_id_seq OWNED BY public.travel_kind_instance.kind_id;


--
-- Name: travel_product; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.travel_product (
    travel_id character varying(30) NOT NULL,
    travel_title text NOT NULL,
    travel_score double precision,
    num_people integer DEFAULT 0,
    travel_price double precision,
    travel_date date
);


ALTER TABLE public.travel_product OWNER TO postgres;

--
-- Name: travel_raider; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.travel_raider (
    travel_id character varying(30) NOT NULL,
    raider_id character varying(30) NOT NULL
);


ALTER TABLE public.travel_raider OWNER TO postgres;

--
-- Name: travel_stoke; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.travel_stoke (
    travel_id character varying(30) NOT NULL,
    travel_step_id smallint NOT NULL,
    travel_copy_id smallint NOT NULL,
    travel_step_detail text
);


ALTER TABLE public.travel_stoke OWNER TO postgres;

--
-- Name: user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."user" (
    user_id character varying(254) NOT NULL,
    user_password character(128) NOT NULL,
    user_name character varying(20) NOT NULL
);


ALTER TABLE public."user" OWNER TO postgres;

--
-- Name: user_image; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_image (
    user_id character varying(254) NOT NULL,
    image_address text NOT NULL
);


ALTER TABLE public.user_image OWNER TO postgres;

--
-- Name: user_raider; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_raider (
    user_id character varying(254) NOT NULL,
    raider_id character varying(30) NOT NULL
);


ALTER TABLE public.user_raider OWNER TO postgres;

--
-- Name: user_save_raider; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_save_raider (
    user_id character varying(254) NOT NULL,
    raider_id character varying(30) NOT NULL,
    save_date date
);


ALTER TABLE public.user_save_raider OWNER TO postgres;

--
-- Name: user_star_raider; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_star_raider (
    user_id character varying(254) NOT NULL,
    raider_id character varying(30) NOT NULL,
    star_date date
);


ALTER TABLE public.user_star_raider OWNER TO postgres;

--
-- Name: user_travel_booking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_travel_booking (
    user_id character varying(254) NOT NULL,
    travel_id character varying(30) NOT NULL,
    travel_price double precision NOT NULL,
    book_date character varying(50)
);


ALTER TABLE public.user_travel_booking OWNER TO postgres;

--
-- Name: user_travel_save; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_travel_save (
    user_id character varying(254) NOT NULL,
    travel_id character varying(30) NOT NULL
);


ALTER TABLE public.user_travel_save OWNER TO postgres;

--
-- Name: raider_comment comment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_comment ALTER COLUMN comment_id SET DEFAULT nextval('public.raider_comment_comment_id_seq'::regclass);


--
-- Name: raider_kind_instance kind_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_kind_instance ALTER COLUMN kind_id SET DEFAULT nextval('public.raider_kind_instance_kind_id_seq'::regclass);


--
-- Name: travel_kind_instance kind_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_kind_instance ALTER COLUMN kind_id SET DEFAULT nextval('public.travel_kind_instance_kind_id_seq'::regclass);


--
-- Data for Name: raider; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.raider (raider_id, raider_title, stars, visits, raider_date, date_between) FROM stdin;
46368	大阪心斋桥攻略,大阪心斋桥门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	3407	2020-07-23	7
110407	墨尔本唐人街攻略,墨尔本唐人街门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	620	2020-07-23	7
13318	东京银座攻略,东京银座门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	3422	2020-07-23	7
13230	东京东京塔攻略,东京东京塔门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	3156	2020-07-23	7
26696	东京新宿攻略,东京新宿门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1868	2020-07-23	7
13125	京都二条城攻略,京都二条城门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1205	2020-07-23	7
13243	东京浅草寺攻略,东京浅草寺门票/游玩攻略/地址/图片/门票价格【携程攻略】	1	4528	2020-07-23	7
1407447	东京秋叶原攻略,东京秋叶原门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1250	2020-07-23	7
190032784020200729838956	北京故宫攻略,北京故宫门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	3	2020-07-29	1
7290	曼谷大皇宫攻略,曼谷大皇宫门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	9736	2020-07-23	7
46367	大阪梅田攻略,大阪梅田门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	414	2020-07-23	7
13598	纽约华尔街攻略,纽约华尔街门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	821	2020-07-23	7
13607	悉尼悉尼歌剧院攻略,悉尼悉尼歌剧院门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2736	2020-07-23	7
13619	悉尼岩石区攻略,悉尼岩石区门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	492	2020-07-23	7
110165	普林斯镇十二门徒岩攻略,普林斯镇十二门徒岩门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	651	2020-07-23	7
22197	大阪日本环球影城攻略,大阪日本环球影城门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	13211	2020-07-23	7
13131	京都清水寺攻略,京都清水寺门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	3007	2020-07-23	7
13144	京都金阁寺攻略,京都金阁寺门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2423	2020-07-23	7
49194	大阪道顿堀攻略,大阪道顿堀门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1753	2020-07-23	7
45087	墨尔本联邦广场攻略,墨尔本联邦广场门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	526	2020-07-23	7
110147	清迈清迈大学攻略,清迈清迈大学门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1990	2020-07-23	7
110373	清迈清迈古城攻略,清迈清迈古城门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1442	2020-07-23	7
136940	清迈素贴山攻略,清迈素贴山门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1283	2020-07-23	7
8142	清迈大佛塔寺攻略,清迈大佛塔寺门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1266	2020-07-23	7
13444	东京东京迪士尼乐园攻略,东京东京迪士尼乐园门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	6953	2020-07-23	7
110499	京都八坂神社攻略,京都八坂神社门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	800	2020-07-23	7
13592	纽约自由女神像攻略,纽约自由女神像门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2015	2020-07-23	7
13590	纽约中央公园攻略,纽约中央公园门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1143	2020-07-23	7
13645	纽约帝国大厦攻略,纽约帝国大厦门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1826	2020-07-23	7
13562	墨尔本皇家植物园攻略,墨尔本皇家植物园门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	430	2020-07-23	7
110158	墨尔本墨尔本大学攻略,墨尔本墨尔本大学门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	243	2020-07-23	7
46387	大阪大阪城攻略,大阪大阪城门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2012	2020-07-23	7
13200	大阪大阪城天守阁攻略,大阪大阪城天守阁门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1657	2020-07-23	7
13591	纽约大都会艺术博物馆攻略,纽约大都会艺术博物馆门票/游玩攻略/地址/图片/门票价格【携程攻略】	1	1744	2020-07-23	7
7311	曼谷四面佛攻略,曼谷四面佛门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	4182	2020-07-23	7
43782	曼谷湄南河攻略,曼谷湄南河门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2594	2020-07-23	7
7292	曼谷玉佛寺攻略,曼谷玉佛寺门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2057	2020-07-23	7
110031	曼谷考山路攻略,曼谷考山路门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2138	2020-07-23	7
7296	曼谷郑王庙攻略,曼谷郑王庙门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1021	2020-07-23	7
110168	清迈双龙寺攻略,清迈双龙寺门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	3240	2020-07-23	7
110443	清迈塔佩门攻略,清迈塔佩门门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	2116	2020-07-23	7
15861	悉尼达令港攻略,悉尼达令港门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1180	2020-07-23	7
13604	悉尼悉尼海港大桥攻略,悉尼悉尼海港大桥门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1064	2020-07-23	7
15869	悉尼海德公园攻略,悉尼海德公园门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	619	2020-07-23	7
13616	悉尼皇家植物园攻略,悉尼皇家植物园门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	810	2020-07-23	7
61258	京都岚山攻略,京都岚山门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1367	2020-07-23	7
110500	京都伏见稻荷大社攻略,京都伏见稻荷大社门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1956	2020-07-23	7
13874	纽约时代广场攻略,纽约时代广场门票/游玩攻略/地址/图片/门票价格【携程攻略】	0	1601	2020-07-23	7
\.


--
-- Data for Name: raider_comment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.raider_comment (user_id, raider_id, comment_id, comment_content, comment_date) FROM stdin;
1900327840@qq.com	13243	2	这个景点很好	2020-07-25
\.


--
-- Data for Name: raider_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.raider_detail (raider_id, raider_step, font_size, raider_detail) FROM stdin;
13243	1	1	浅草寺是东京历史最悠久、人气最旺的寺院，也是浅草地区的中心，供奉的本尊是圣观音。它始建于7世纪，因屡遭火灾，后被重建。相传因三位渔民出海捕鱼时捞起了一座约5.5厘米高的金观音小雕像，才修建了这座庙宇。
13243	2	1	风雷神门 浅草寺的象征是入口处的风雷神门，左右分别是镇守寺院的风神和雷神，大门上挂着写有“雷门”两字的巨大红灯笼，非常气派。门后挂着两个巨大的草鞋。
13243	5	1	雷门
13243	6	1	仲见世商店街 门内是通往寺庙广场的仲见世商店街，一字排开的诸多店铺摆满了各种日本风情的小商品，如传统的扇子、纸制的小玩意等。这是东京最热闹的购物街之一，很多游客在这里一边观赏一边挑选精美的工艺品。
13243	9	1	仲见世商店街
13243	10	1	本堂 来到浅草寺主广场会看到宝藏门，从这进去是百来米的铺石参拜道，通向供奉观音像的本堂。广场上有一个巨大的香炉，很多人往自己身上扇烟，以庇护健康。本堂的屋顶很有特点，有明显的倾斜度，屋脊显得相当高耸，造型结构鲜明醒目。东边不远处的另一个出入口叫二天门，是国家指定的重要文化财产。
13243	13	1	五重塔 本堂的西南边是五重塔，最上层藏有释迦牟尼佛的舍利子。再往西南角是传法院，以其美丽的庭园著称，不过很可惜这里不对外开放（过去可以预约参观，但现在已经不行了）。本堂东北边是浅草神社，可以自由参观，每年5月都有热闹非凡的“三社祭”。
13243	16	1	此外，浅草寺内还有许多著名建筑物和史迹，值得细细观赏。
13318	1	1	银座是东京最著名的商业区，也是日本最具代表性的繁华商圈，以高级购物商店而闻名，聚集了顶级大牌旗舰店、高档百货和各种百年老店等，与巴黎香榭丽舍大街、纽约第五大道齐名，可以在各种影视镜头中看到银座的景象。
13318	2	1	银座有8条大街，从一丁目到八丁目由中央大街贯通，其中又以四丁目十字路口最为繁华。每到周六、周日，从中午到傍晚，银座的主要道路禁止车辆通行，变成“步行者天国”。银座作为日本高档消费的代名词，令无数游客流连忘返，然而随着平价品牌店铺的陆续登陆，银座也变得更加“平民化”。
13318	3	1	中央大街（中央通り）是银座最主要的街道，一般说的银座大街（銀座通り）也就是指这里。以中央大街和晴海大街相交叉的银座四丁目十字路口为中心，和光、三越、松屋等高档百货店、高级珠宝店及高级餐厅鳞次栉比。和光百货是银座的一大地标，采用新文艺复兴式样的大楼顶部是一台石英大钟，很有特色；这家老字号商场销售高档名贵服装、珠宝及其他奢侈品，讲究精品的话一定要来看看。马路对面的三越百货主打时尚牌，更加适合追赶时髦的年轻人。而晴海大街（晴海通り）是仅次于中央大街的繁华街道，著名的索尼大厦就在这里。你可以在大厦展示厅里自由体验最新的数码产品。
13318	4	1	和光
13318	5	1	松屋
13318	6	1	晴海大街南侧的并木大街（並木通り）一带是许多成功人士和社会名流经常光顾的地方，你会发现Hermès、Chanel、Dior、Gucci、Louis Vuitton等世界顶级名牌几乎全部集中于此，时尚奢华气息尽显无疑。在Hermès旗舰店里可是有其他地方买不到的“银座限定”商品。而并木大街和悬铃木大街沿线还分布着很多有名的画廊。
13318	7	1	除了顶级时尚大牌，资生堂、Fancl等化妆品和优衣库、Gap、H&M等流行服饰的旗舰店也在银座扎堆。此外，还有许多传统老店也值得一逛，如以出售纸工艺品为代表的鸠居堂、经营各式文具及纪念品的伊东屋。
13318	8	1	资生堂
13318	9	1	Fancl
13318	10	1	优衣库
13318	11	1	Gap
13318	12	1	鸠居堂
13318	13	1	伊东屋
13318	14	1	作为东京数一数二的高消费区，银座当然也云集了很多高级餐厅，预算充足的话可以尝尝顶级料理过把瘾。纪录片《寿司之神》中讲述的寿司店数寄屋桥次郎就在这里。
13318	15	1	数寄屋桥次郎
13318	16	1	银座还有许多电影院、Club等休闲场所。在位于四丁目的歌舞伎座可以观看高水准的歌舞伎表演，是很特别的体验。整套表演需要提前预定（门票4000-22000日元不等），单一幕表演可以当天直接去看（门票2000日元左右）。表演分日夜场，详情可查询：http://www.kabuki-za.co.jp/ticket/。
13318	17	1	http://www.kabuki-za.co.jp/ticket/
13318	18	1	各店铺的关门时间较早，一般20:00左右就不开了。入夜后五光十色的霓红灯又给银座增添了几分魅力，21:00左右是酒吧开始营业的时间，奢华的氛围在夜晚继续蔓延。
13230	1	1	东京塔也叫东京铁塔，正式名称为日本电波塔，是东京观光必游景点。这座红白色铁塔以巴黎埃菲尔铁塔为范本而建造，但比后者高9米，达333米；1958年竣工后一直是东京最高的建筑物，直至2012年东京晴空塔建成而退居第二。 作为东京的标志之一，东京塔的形象和名字也频繁出现在影视剧、小说、音乐等艺术作品中。
13230	2	1	东京晴空塔
13230	4	1	眺望厅 东京塔眺望厅分为大眺望厅（150米）和特别眺望厅（250米），能360度将东京的城市景观尽收眼底，高楼建筑、公园、寺院神社、东京湾、远处的群山等等一览无遗，若是晴好天气还能远眺富士山、筑波山。在塔底有直达大眺望厅的电梯，若要上到特别眺望厅，需先在大眺望厅购买门票，再换乘电梯。 乘坐电梯首先到达的是大眺望厅2楼，这里有双筒望远镜出租，可以携带至所有眺望厅。这里还有一个小型神社，据说祈求恋爱顺利和考试及格很灵验。而在纪念品商店可以买到东京塔模型、吉祥物Noppon等各种商品。另外，特别眺望厅的售票处也在这层，上到特别眺望厅俯瞰东京的大街小巷效果更佳。 下到大眺望厅1楼，你可以体验一把玻璃地板“俯视窗”的惊险感受。这里还设有咖啡厅“Café La Tour”，你可以一边自在地喝咖啡（价格不贵），一边眺望风景；还有“Club333”专用舞台，每周都定期举办丰富多彩的节目和活动，你可以在与夜景相得益彰的音乐中度过时尚之夜。节目安排详见：http://www.tokyotower.co.jp/cn/club333/index.html。 亮灯和灯彩 东京塔塔身有“陆标亮灯”和“钻石亮灯”2种亮灯，陆标亮灯是常规方式，冬日是温暖的橘色，夏日则是凉爽白色基调散发的光芒，每天日落-24:00都会点亮。钻石亮灯会变换7种颜色，发出宝石般的光芒，一般只在周六的20:00-22:00这段时间点灯两小时，灯光颜色依季节和活动内容有所调整。 此外，东京塔每年都会举办数次主题不同的点灯活动。 #Tokyo Warm Light# 4月-5月左右在大眺望厅1楼举办。以“温暖”为主题，大眺望厅亮起温馨的灯彩，悄然融入夜色之中而不张扬。不妨在会场一角的“Tokyo Warm Heart”灯饰前来张合影吧。 #银河灯彩# 6月初-7月10日左右在大眺望厅1楼举办。“七夕”时，有蓝色星空般的灯彩将大眺望厅笼罩起来，还有将星空一切为二的白色银河灯彩。 #圣诞灯彩# 11月3日-12月25日在东京塔正面大门前举办。围绕在大型圣诞树周围，除了圣诞老人和驯鹿，还有银河铁道和埃及方尖碑等各种灯彩图案，与圣诞歌曲交织在一起。每年圣诞节都有许多恋人在此度过浪漫之夜。 每当夜幕降临，塔身会点亮（一般从日落到午夜零点），随季节变换不同颜色，令东京的夜色更加梦幻。东京塔每年还会举办灯彩活动，如果恰巧赶上了，一定会留下难忘的回忆。
13230	9	1	http://www.tokyotower.co.jp/cn/club333/index.html
13230	25	1	东京塔底部 东京塔底部叫Foot Town，有商店、餐厅等设施。这里还有一处海贼王主题公园“Tokyo One Piece Tower”，你可以在此体验“千阳号”等各种游乐设施、观赏现场娱乐表演、享受海贼美食和购买限定商品。
26696	1	1	新宿是东京最著名的繁华商区之一，不仅有数不尽的商场和大厦，还有赏樱地新宿御苑、富有文艺的黄金街及歌舞伎町等知名景点。充满绮丽色彩的新宿都能满足你对东京的所有想象，而《迷失东京》等多部电影也曾在这取景。
26696	2	1	新宿御苑
26696	3	1	黄金街
26696	4	1	歌舞伎町
26696	5	1	游玩新宿一般是从新宿站开始，这是日本最繁忙的火车站，连通着十余条铁路和地铁线。以此为中心，分为新宿东口、南口和西口3个商业区，无论在地上还是地下都有十分密集的商业设施，名牌店、百货商场、电器街、药妆店、百元店、折扣店、潮流服饰店等应有尽有，各种档次一应俱全，加上居酒屋、咖啡厅等众多餐馆，玩上一整天也不为过。晚上的新宿像是一座不夜城，灯火辉煌的气氛中弥漫着迷人的魅力。
26696	6	1	车站西边是新宿的摩天大楼区，耸立着京王、希尔顿、凯悦等一流酒店及高层办公楼，而新宿的一大地标——东京都厅也在其中。这是东京的政府大楼，顶层设有免费开放的东京都厅展望台，可以360度鸟瞰东京都，看夜景很不错。都厅以北不远的I-Land Tower前有一个LOVE雕塑，是日剧《电车男》中出现过的场景，感兴趣的话可以过去瞧一瞧。
26696	7	1	东京都厅展望台
26696	8	1	LOVE雕塑
26696	9	1	从新宿站往东北边走不久就是日本最著名的歌舞伎町，每到夜晚，可以看到纷繁复杂的霓虹灯招牌、各种风俗店及形形色色的人，令人感慨万千，不过为了安全不建议太晚前去。
26696	10	1	紧邻歌舞伎町有一条新宿黄金街，开着很多复古的店铺，文艺气息十足，可以淘一淘有意思的小物品。这里还有一座花园神社，地方不大，但不少人会到此祈福。
26696	11	1	花园神社
26696	12	1	如果想满足一下自己的购物欲，集中在新宿站周围的小田急、京王、伊势丹、高岛屋等百货商场都是不错的选择，还有专卖电器的Yodobashi和Bic Camera，一般从10:00营业至22:00。
26696	13	1	小田急
26696	14	1	京王
26696	15	1	伊势丹
26696	16	1	当然，你也可以度过清闲的时光，不妨往新宿站东南边走，到新宿御苑去游玩吧。这块城市绿洲春季是赏樱胜地，秋季有大片红叶，而盛夏浓郁的绿色同样赏心悦目，可以领略到现实版的《言叶之庭》哦。
26696	17	1	另外，早稻田大学、东京医科大学等高等学府也位于新宿区，逛街之余可以游览一下日本名校。
26696	18	1	早稻田大学
26696	19	1	在餐饮店数量号称日本第一的新宿，美食的选择十分丰富。这里也是东京拉面激战区之一，从新宿站西口往大久保站方向延伸的小泷桥大道（小滝橋通り）上，有面屋武藏、味增屋八郎商店、蒙古汤面中本（蒙古タンメン中本）等大量人气面馆，而且价格实惠。
26696	20	1	面屋武藏
1407447	1	1	秋叶原是世界上最大的电器商业街区，沿街分布着大大小小几百家电器店，出售最新型的电脑、相机、电视机、手机、家用电器等，品种相当齐全。日本高人气偶像团体AKB48的专属剧场也位于此，可以买到许多AKB48的相关商品。
1407447	2	1	这里也是日本动漫文化的发祥地，遍地都是动画、漫画、电玩、手办商店，还有很多偶像系店铺、动漫咖啡馆、女仆咖啡馆等，常能看到Cosplay的少男少女，是御宅族和动漫迷的一大“圣地”。
1407447	3	1	走出秋叶原车站，你会看到满大街的电子产品及动漫商品的海报。主干道上有好几家大型电器连锁店，如友都八喜、秋叶原电台会馆、石丸电器、Sofmap等，而规模较小的店铺则在偏僻一点的街巷里，你还可能看到同一家品牌的好几个分店。
1407447	4	1	友都八喜（Yodobashi Akiba） 你可以逛逛车站东侧的友都八喜，在这个大商城里不仅有各种最新的电子产品、手办、玩具，还有高档手表、名牌包、化妆品等商品，有的店员还会说中文，并提供免税服务，非常受游客欢迎。逛累了可以到顶层餐厅吃寿司、大阪烧等特色美食。 地址：東京都千代田区神田花岡町1-1。 营业时间：9:30-22:00。
1407447	9	1	秋叶原电台会馆（秋葉原ラジオ会館） 车站西侧的秋叶原电台会馆也是高人气的商场，除电子产品外，大批的动漫系店铺是一大特色。 地址：東京都千代田区外神田1-15-4。 营业时间：10:30-19:30，周四休息。
1407447	14	1	Gachapon会馆（秋葉原ガチャポン会館） 这家店拥有几百台玩具自动贩卖机，你可以在此淘到面包人、高达、假面骑士、皮卡丘、肌肉人、新世纪福音战士等周边商品，有些还是稀有物件，买来珍藏或作为手信送人都很不错，另外，这里的关东煮自动贩卖机也很出名。 地址：東京都千代田区外神田3-15-5 ジーストア・アキバ1F。 营业时间：平日11:00-20:00，周五、周六、节假日前一天11:00-22:00，周日、节假日11:00-19:00。
13444	40	1	#焰火表演# 在接近闭园时的压轴节目。迪士尼交响名曲与绽放夜空的硕大焰火交织成公主梦。很多人在开始前就聚集到乐园中心的水晶城堡前了。
61258	3	1	标志性景观——渡月桥
1407447	19	1	UDX大楼（秋葉原UDXレストラン&ショップ） 另一家必逛的UDX大楼，位于车站北面。大楼内的东京动画城（Tokyo Anime Center）售卖各种动漫角色的限定商品，经常举行各种企划展、声优的脱口秀、动漫上映等相关活动，甚至还能听到电台的非公开录音。还有SEGA GiGO、TAITO STATION等厂商开设的电玩中心，不仅有最新款的游戏机，还有娱乐展示区和体验区。如果你日语够好的话，可以在动漫店里体验一把配音。记得看看来过这里的各种演员、声优的签名收银台看板，很有意思。大楼内还有Akiba Ichi美食街，聚集了许多名店、老店，能吃到烤鸡肉串、鳗鱼、天妇罗、炸猪排、荞麦面、海鲜等日本料理和中式、意式、美式等各国美食。 地址：東京都千代田区外神田4-14-1。 营业时间：11:00-23:00，周日、连休假日的最后一天11:00-22:00。
1407447	24	1	主题咖啡馆也是来到秋叶原一定要体验的，店内有模仿动漫、游戏情节的场景以及出场人物装扮的服务生，你可以一边品尝美味一边挑选周边商品。
1407447	25	1	高达咖啡馆（Gundam Cafe） 位于车站北侧，可以品尝用南美咖啡豆做出的“Jaburo咖啡”等，还有以高达原型1:144微缩的“高达烧”。 地址：東京都千代田区神田花岡町1-1。 营业时间：平日10:00-23:00，周六8:30-23:00，周日、节假日8:30-21:30。
1407447	30	1	AKB48 Cafe & Shop 就在高达咖啡馆旁边，喝咖啡、吃甜点之余还能买到各种偶像周边商品。 地址：東京都千代田区神田花岡町1-1。 营业时间：周一-周四11:00-22:00，周五、节假日前一天11:00-23:00，周六10:00-23:00，周日、节假日10:00-22:00。
1407447	35	1	Cure Maid Cafe 这可是日本第一家女仆咖啡馆，以“治愈”为概念，很受好评。周六晚上有现场演奏，有时还会举行动漫、游戏系列活动，届时会有特色食谱。 地址：東京都千代田区外神田3-15-5 ジーストア・アキバ6F。 营业时间：周一-周四11:00-20:00，周五、周六、节假日前一天11:00-22:00，周日、节假日11:00-19:00，不定期休息。
1407447	40	1	如果你是AKB48的粉丝，就绝不能错过AKB48剧场，就在UDX大楼的西对面，几乎每天都有公演。演出门票采取E-mail预购制，详情可见：http://www.akb48.co.jp/theater/ticket.php。
1407447	41	1	http://www.akb48.co.jp/theater/ticket.php
13444	1	1	东京迪士尼乐园是东京迪士尼度假区的主要部分，也是目前营运较成功的迪士尼乐园之一。从主建筑“灰姑娘城”进入游乐园，开始一段忘我的童话之旅吧！ 除了各种充满仙境般梦幻气息的娱乐设施外，经典卡通人物的表演和盛装游行也相当精彩，园区还定期举行年度活动，尤其圣诞、新年期间的特别活动格外吸引人，不同年龄层的游客都能在此找到乐趣。
13444	4	1	玩游乐项目 迪士尼乐园分为世界市集、探险乐园、西部乐园、动物天地、梦幻乐园、卡通城、明日乐园，这7个区域中可玩性较高的要数明日乐园了，尤其推荐“星际旅行”和“太空山”。 #星际旅行# 以星球大战为背景，制作精良的3D效果让你身临其境，十分震撼，而且有50多种剧情随机提供，几乎每次玩都有全新感受。 #太空山# 这是让你能翱翔在宇宙的室内过山车，属于迪士尼经典项目，人气超高。 另外，如果你是Michael Jackson的粉丝，不要错过该区域的“伊欧船长”哦，在这个项目里能欣赏到外面看不到的MJ珍贵影像。 如果你不太敢玩过于刺激的项目，可以试试下面2个项目—— #加勒比海盗# 位于探险乐园，乘着小船进入海盗冒险世界。这个大型地下游乐项目入口很小，很多人会错过，好在排队速度较快。 #巨雷山# 位于西部乐园，这个过山车算不上非常刺激，但玩一次还是很欢乐的。 你也可以在梦幻乐园里重返童年。坐上“小飞侠天空之旅”的缆车，仿佛真的在飞。人气项目“小熊维尼猎蜜记”虽然香港也有，但这里更胜一筹。如果玩累了，可以看个3D电影休息休息。带小孩的话，还可以直奔卡通城，几乎是专为孩子们设计的，可以在这里玩很久呢。
13444	26	1	看娱乐表演 来东京迪士尼不仅是玩项目，各种高水准的表演更是精华所在，与国内游乐园的差距一下就拉开了。即便你玩High了顾不上看演出，也绝不能错过日夜两个大游行和焰火表演哦。 #日间游行# 是迪士尼群星的花车巡游，超具亲和力的互动是它的一大特色。路线是固定的，你可以提前对照地图找个位子等待这份惊喜哦。
13444	34	1	#夜间游行# 是由上百万个彩灯组成的花车队伍，比白天更梦幻！也是固定路线的，但如果碰到下雨天演出会被取消。不过别担心，迷你夜间游行“夜幕彩辉”是专门为雨天准备的，有着别样的浪漫。
13591	11	1	欧洲绘画展厅
13444	46	1	餐饮 游乐园里有很多主题餐厅，有的提供中文菜单，有的还提供儿童餐，种类繁多。部分餐厅里还有迪士尼明星可以合影。乐园经常推出限定食物，各种迪士尼卡通造型的点心让你都不忍心吃掉呢。另外，这里的烤火鸡腿平常应该很少吃到，很有特色而且比较饱腹，可以参照园区地图找到售卖点。
13444	49	1	购物 五彩缤纷的迪士尼商品都能在游乐园里买到，其中有些是迪士尼限定的，外面可买不到哦。特别是游戏限定的商品只有在游乐项目附近的商店里才有卖。接近闭园时是购物的高峰期，你可以在晚上娱乐表演快结束的时候去。
13444	52	1	住宿 如果想将东京迪士尼玩透，不妨在度假区或附近住下。度假区内有3家迪士尼饭店和6家公认饭店（皆在2个游乐园外面），度假区外附近也有多家合作饭店，可以自行在官网查询。虽然即便入住迪士尼饭店也没有门票优惠，但3家迪士尼饭店和6家公认饭店的住客可以在饭店内直接购买或兑换2个游乐园的门票，而且享受入园保证（当游乐园人流过多实施入园限制时依然可以入园），而3家迪士尼饭店的住客还可以凭房卡和门票在开园前15分钟优先从酒店专用入口进入游乐园。 东京迪士尼度假区 度假区里还有东京迪士尼海洋，是一个以“海洋”为主题的游乐园。“乐园”和“海洋”各有7大主题区域，相对来说前者偏低龄化，后者更适合成年人。
13444	59	1	除了两座巨型游乐园，这里还有主题购物中心、剧场和酒店。
46368	1	1	心斋桥位于大阪市中央区，是大阪最大的商业购物区，以心斋桥筋商业街为中心，北至长堀通、南至道顿堀，集中了许多精品屋、专卖店、餐馆和大型购物中心，从早到晚都有熙熙攘攘的市民和游客。 逛街购物之余，品尝地道的大阪美食也是一大乐事，你可以敞开肚子吃大坂烧、串炸、章鱼烧、拉面等日式料理，也可以尝到亚洲其他地区以及欧美等世界各国的风味。这里还有电影院、剧场等成片的娱乐设施，是体验大阪夜生活的好去处。
46368	3	1	心斋桥筋商业街一带 心斋桥车站出来就是心斋桥筋商业街，南北走向，长约600米。它有着封闭的透光拱廊，即便刮风下雨也可以放心逛。石板人行道、英伦风格的路灯以及成排的砖造建筑物等格调高雅，也被人们叫做“欧洲村”。从大型百货店、百年老铺到平价小店鳞次栉比，流行时装、药妆、箱包、首饰、杂货、食品等应有尽有，非常适合旅游购物。心斋桥筋商业街旁边的小巷子也可以逛逛，会找到一些有意思的小店。 在道顿堀戎桥上可以看到两块有近百年历史的“雪印”和“格力高跑步者”招牌，是心斋桥的一大标志，记得要合影哦（《半泽直树》等日剧也曾在这取景）。每到夜晚，五彩缤纷的霓虹灯和闪动的广告牌让这里充满了无限的活力。 如果往车站北侧走，可以到达南船场一带，这里集中了不少世界名牌专卖店，如Cartier、Chanel、Hermes等顶级品牌。东急Hands百货店有海量的日用杂货及文具等商品可供挑选。还有库利斯塔长堀地下街（Crysta Nagahori），是日本规模最大、采光最好的地下商业街，自然光可以直接照射进来，营造了明亮、舒适的购物环境。 车站南面是大丸百货心斋桥店，它有着怀旧感的历史建筑风貌，店内气氛优雅，不仅能够买到很多世界名牌，也有很多价格实惠的日常生活用品可以选购。而马路对面的心斋桥OPA是心斋桥一带有名的时装购物商场，内有时装、首饰、鞋帽、化妆品等约110家店铺。 继续往南可以到达周防町通，这是一条东西走向的小街，横贯心斋桥筋商业街和御堂筋大街。两边是高雅的欧式服装店、独具风情的咖啡厅、餐饮店等，整个街区的氛围优雅闲静，来此逛街购物、喝咖啡看街景是十分惬意的。
46368	9	1	大丸百货心斋桥店
46368	11	1	美国村 心斋桥的西侧则是美国村，集中了很多不拘一格的时髦服装店、旧货店、唱片店以及各种俱乐部等娱乐设施。这里纽约街头元素浓重，随处可见造型洋气、身着热裤的少女和嘻哈少年，代表着大阪年轻人的时尚文化。
46368	14	1	美国村
46368	15	1	道顿堀 沿着心斋桥筋商业街往南走到底就到了道顿堀，这里是大阪人所说“吃趴下”饮食文化的发源地，餐饮店非常多，而且价格合理，人气极旺。最有名的蟹道乐“大螃蟹招牌”是道顿堀美食街的标志，一定要尝尝这家的美味。虽然大多餐馆的门面都不大，但食物的品质可不会因此而缩水哦。
46368	18	1	道顿堀
46368	19	1	蟹道乐
22197	1	1	日本环球影城是以好莱坞电影为主题的大型主题乐园。你可以通过乘坐各种惊险的游乐设施、观看精彩绚丽的表演秀来体验电影场景，如飞檐走壁的蜘蛛侠、侏罗纪公园里的恐龙、突然袭船的大白鲨、近在咫尺的终结者等。 精彩亮点 哈利波特的魔法世界主题园区让日本环球影城人气高涨，不仅高度还原了原作场景，新增了许多高水准的游乐设施，还有“霍格沃茨”魔法学校的街头表演，而大量精美的周边商品也是让人兴奋不已。2016年开设的“飞天翼龙”过山车热度不减，喜欢刺激挑战的朋友不妨尝试一次。
22197	6	1	哈利波特的魔法世界
22197	7	1	另外，偶像团体SMAP亲自体验过的倒着开的音乐过山车、再现了电影中惊险特技的水世界表演、夜晚的星光大游行等，也都不容错过。
22197	8	1	2017年4月开张的小黄人主题园一路人气高涨。除了可以搭乘设施在小黄人的世界里穿梭，还可以遇上比如小黄人街头演出、特别表演等，再买些可爱的小黄人主题小吃，完全沉浸在电影的奇妙世界中。
22197	9	1	大阪环球影城近年来都会推陈出新，每年会安排数个为时5-6个月的期间限定活动，比如4D的哥斯拉、进击的巨人、EVA、怪物猎人等等全新制作的项目，奉献一场感官盛宴。另外还有继承超高人气死亡笔记密室解谜的柯南密室项目，非常值得一玩，不过需要一定的日语基础。
190032784020200729838956	1	3	景点介绍
22197	11	1	如何前往和游览路线 前往环球影城的交通很方便，搭乘JR梦咲线即可到，这辆电车的车身就涂绘着电影人物的形象。乐园分为好莱坞区、纽约区、旧金山区、侏罗纪公园、水世界、亲善村、环球奇境、哈利波特的魔法世界等区域，总体上不算太大，但建议避开周末、节假日前往。 入园后，可以从左手边开始顺时针游玩，几乎每个区域里都有惊险的游乐设施。日本环球影城导览图：http://www.usj.co.jp/cn/common/studiomap.html。 下面推荐一些必玩的人气区域、游乐设施及演出。
190032784020200729838956	2	1	绝大多数刚来北京的游客，都会把故宫当作必去之处。故宫又称紫禁城，是明、清两代的皇宫，也是古老中国的标志和象征。当你置身于气派规整的高墙深院，能真真切切地感受到它曾经的荣耀。悠久的历史给这里留下了大规模的珍贵建筑和无数文物，也成为今天游玩故宫的主要看点。
190032784020200729838956	3	2	游览古建筑群
190032784020200729838956	4	1	故宫是中国乃至世界上保存较为完整、规模较大的木质结构古建筑群。这些金碧辉煌的建筑群可以分为“外朝”与“内廷”两大部分。以乾清门为界，乾清门以南为外朝，是皇帝处理政务的地方，乾清门以北为内廷，住着后宫嫔妃，是皇帝家庭生活之所。走过金銮殿、乾清宫、坤宁宫，在皇帝的御花园里赏弄花花草草，感觉好像穿越到了古装剧里。
22197	15	1	http://www.usj.co.jp/cn/common/studiomap.html
190032784020200729838956	5	1	欣赏大量的珍贵文物
22197	17	1	哈利波特的魔法世界 威严壮丽的“霍格沃茨”城堡，是这个主题园区的标志性建筑。走进城堡，穿过魔法学校的教室和走廊，去探访“邓布利多的校长室”和“黑魔法防御术教室”等房间，途中“会动的肖像画”和“分类帽”还会和你搭话，就像进入了真实的电影世界里！ 这里的游乐设施包括带给你超真实感官的“哈利波特禁忌之旅”、适合全家乘坐的“鹰马的飞行”等，不仅能感受到先进科技的魅力，更会被电影般的体验而感动。最近还新开放了参观城堡的路线，不用排队、不用存包就可以进去逛一圈，还能用相机拍拍拍。 此外，园区里还有魔法学校的学生们优美动人的合唱、魔法对抗赛等现场表演，让人舍不得把目光移开。你还可以在“三根扫帚酒吧”和“猪头酒吧”品尝到魔法世界里的奶油啤酒（不含酒精），在一系列的魔法商店买到各种魔杖、恶作剧道具等充满惊喜的纪念商品。
190032784020200729838956	6	1	故宫内珍藏有大量珍贵文物，据统计有上百万件。以文物的种类不同，分为多个展馆。其中珍宝馆和钟表馆很是引人注目，钟表馆每天11点和14点有钟表演示，可以看到清王朝珍藏的各种造型奇特的珍奇机械钟表，一定令你眼界大开。
22197	22	1	好莱坞美梦过山车 该设施位于好莱坞区，这个过山车有两种运行模式，一种是正着开，一种是倒着开，非常特别和刺激；你还可以选择背景音乐，会在运行过程中播放，十分有趣。具体运行模式时间请参照当天乐园公告。
22197	25	1	蜘蛛侠惊魂历险记 该设施位于纽约区，这个飞车曾连续7年荣获金券奖最佳室内娱乐设施，在乘坐飞车的同时观看4K高清3D影像，穿梭在高层建筑间的蜘蛛侠还会突然跳到你眼前，非常逼真，100多种特技镜头让人分不清虚拟与现实。
22197	28	1	侏罗纪公园 在这个园区，乘船进入遍布着热带雨林的侏罗纪公园，一路上会看到各种逼真的恐龙，有的很可爱，有的却十分吓人，最后还会从25米多高的地方坠落。 在这个区里，2016年最新开设了飞天翼龙过山车，有着世界最长和最大落差的飞行式过山车之称。最大特点是需要呈180度俯卧式搭乘过山车，模拟被翼龙抓住背部狂奔的场景，非常惊险刺激。不过排队时长动辄180分钟，也是需要排队的勇气。
22197	32	1	大白鲨 该设施位于亲善村，也是坐着船航行在平静的港湾上，然后在不经意间将突然遭遇巨大食人鲨的袭击。若是在夜幕降临后游玩，会更加刺激。
22197	35	1	水世界 这个大型户外演出再现了电影中千钧一发的打斗场面，还有快艇、水上摩托艇飞速行驶，全身烧成火球的特技演员从高处跳入水中，简直就像是现场版的好莱坞大片。一般在下午表演2场，每场时长20分钟，人气很高，记得要提前入场。
22197	38	1	环球奇境 如果带小孩的话，可以到乐园中部的“环球奇境”区域玩很久，这里有以史努比、Hello Kitty、芝麻街等为主题的轻松游乐设施，非常梦幻。
22197	41	1	魔幻星光大游行 夜幕降临后，开始星光大游行，你会被五彩缤纷的灯光和动听的音乐所包围，有“爱丽丝梦游仙境”、“一千零一夜”、“灰姑娘”等童话场景。一般是在19:30左右开始，从好莱坞区一直到纽约区，时长约1小时。
22197	44	1	除以上推荐的，乐园里的魔鬼终结者、史瑞克等多媒体演出也很精彩。乐园规定不能携带食物、饮料入内，你可以在园内的主题餐厅里用餐，价格适中。
46387	1	1	大阪城也叫“金城”或“锦城”，是大阪最著名的旅游观光景点，也是大阪的象征。它位于大阪市中央区的大阪城公园内，与名古屋城、熊本城并列为日本历史上的三大名城。丰臣秀吉统一日本列岛后，于1583年开始修建大阪城来彰显自己的权力，后数次被摧毁，现在看到的是1931年重建的。 整个大阪城分为内城、中城与外城（即本丸、二之丸、三之丸），气势恢宏的城门、高大陡峭的城墙及内外两道宽阔的护城河十分壮观，其他任何一座日本古城都无法与其相比。尤其护城河上长达12公里的城墙，用大量的巨石堆砌而成，极其雄壮，令大阪城固若金汤。 天守阁 中央的天守阁是大阪城的核心建筑，白色的墙面配以绿色的屋瓦，每个飞翘的屋檐末端都装饰着用金箔塑造的老虎和龙头鱼身的金鯱造型，可谓金碧辉煌。天守阁共8层，内部已改建为一个博物馆，是了解丰臣秀吉这位日本战国时代枭雄的最佳地点。顶层（第8层）是距离地面约50米的展望台，可以俯瞰大阪城、眺望大阪街景；其它楼层可以观赏关于丰臣秀吉和大阪的丰富展品。 第1层有一个小剧场，依次放映5部有关丰臣秀吉和大阪城的节目（有中文字幕）；第2层介绍大阪城及日本城堡的基础知识，你也可以在这里试穿头盔、阵羽织、和服来拍照（300日元一次）；第3、4层展示丰臣秀吉及战国时代的重要史料（藏品每两个月更换一次）和不同时期大阪城的复原模型，这两层是禁止拍照的；第5层通过影像和微缩模型生动地介绍大阪夏季之战；第6层是回廊，禁止入内；第7层是丰臣秀吉修筑大阪城、完成日本统一的相关史迹；第8层为展望台，视野极佳。 游玩看点 天守阁以南约100米的地方有一个有意思的东西，是1970年大阪世博会时埋在这里的两个“时间胶囊”（Time Capsule Expo '70），里面装有作为20世纪现代文明的标志性作品，定于5000年后打开。 大阪城的南边有为纪念丰臣秀吉而建的丰国神社，西边有赏樱名所西之丸庭园，东边有大阪市内规模最大的梅林；而城中的大手门、千贯橹等13座建筑物还被指定为日本国家重要保护文物。 园内还有户外音乐堂、体育馆、弓道场、棒球场等公共设施。 赏花 大阪城公园内广栽各种树木，每逢花季是赏樱、赏梅的胜地，吸引了各国游客，很多大阪市民还爱来此观赏水边的野鸟。公园里种植了1250株梅树、4500株樱树，2月中旬-3月上旬可以赏梅，3月底-4月中旬可以赏樱。10月中旬-11月中旬还有规模盛大的“大阪城菊花节”。 西之丸庭园曾是丰臣秀吉的正妻北政所的住处，四周树木环绕，在此能望到天守阁和护城河的石墙等美景，需单独购票进入。这里也是著名的赏樱胜地，3月底-4月中旬，以染井吉野为主的约600株樱花竞相开放，花期约一周，其间还会举办赏夜樱的活动。 大阪城公园里的梅林经过修剪显得低矮、宽阔，无需特意抬头看花。观赏期为2月中旬-3月上旬，可以免费欣赏。
46387	6	1	天守阁
13131	6	1	年被列入世界文化遗产名录。本堂前悬空的清水舞台是日本的珍贵文物，四周绿树环抱，春季时樱花烂漫，是京都的赏樱名所之一，秋季时又化身为赏枫圣地，红枫飒爽，无比壮丽。
13131	9	1	来到音羽山下，沿着小道步行上山。进入清水寺境内，会经过仁王门、西门、三重塔、随求堂、开山堂等建筑，能看到仁王像、地藏佛等雕刻。寺内有很多游客在点香、求签，香火很旺。此外，游客还可以进入随求堂的地下室，体验有名的“胎内漫步”，寓意在菩萨体内祈祷。
13591	13	1	位于二楼，在拍照留念之后不妨坐下来静静欣赏大师们的杰作。
49194	1	1	道顿堀位于心斋桥的南端，是大阪最繁华的商业区之一，也是地标级的美食据点，拉面、章鱼烧、铁板烧、烤肉炸串、旋转寿司、河豚料理及各种甜点应有尽有。 道顿堀川运河两侧密布的巨型广告牌也是这里的一大看点，最著名的要数格力高人形看牌和蟹道乐的大螃蟹招牌。到了霓虹灯闪烁的夜晚，这里更是热闹非凡，你还可以坐观光船来游览两岸夜景。 餐厅推荐 作为大阪“吃趴下”饮食文化的发源地，道顿堀会是你享用美食的首选之地，在心斋桥血拼后到此犒劳一下自己的胃真是再好不过了。你会注意到很多店家的招牌都是立体的，除了知名的“大螃蟹”，还有绿色的龙、握着鲔鱼寿司的巨手、特大的饺子等造型，非常生动，光看起来就让人垂涎欲滴。也有许多不起眼的小店，同样能吃到令人满意的美味。 蟹道乐（かに道楽）在东京、京都等地都有分店，就连道顿堀也有三家店面，但招牌最大的那家才是本店。这里的晚餐消费较贵，人均约6000-8000日元，而午市套餐就比较划算，人均约3000-4000日元。一份套餐可以吃到不同做法的螃蟹，如生蟹肉、煮蟹肉、蟹肉焗饭、铁板蟹等。另外店门口卖的烤蟹脚也非常好吃哦。 而门口总是排着长队的金龙拉面（金龍ラーメン）同样值得推荐，便宜又好吃，人均消费不到1000日元。还有铁板烧的元祖波天久（ぼてぢゅう）、能体验制作章鱼烧的名店Konamon Museum（コナモンミュージアム）、超赞的饺子店大阪王将等，让人眼花缭乱。
49194	2	1	心斋桥
49194	4	1	蟹道乐
49194	12	1	休闲观光 在满足味蕾之余，你还可以逛逛法善寺横丁，感受别样的江户时期街道风情，拜一拜不动明王菩萨；或者参观一下附近充满艺术气息的上方浮世绘馆；在运河北岸还有一个惹眼的椭圆形财神爷摩天轮，那是唐吉诃德（ドン・キホーテ）百货店的附属设施，感兴趣的话可以花600日元坐一次。 乘坐水上观光船来游览道顿堀川两岸风光也是一个不错的选择。太左卫门桥下是搭乘点，就在财神爷摩天轮旁边，票价为700日元，如果你买了大阪周游卡可以免费乘坐。运营时间为平日13:00-21:00，周末、节假日及繁忙时期11:00-21:00，每半小时一班，航程20分钟。尽管是日语讲解，但活力四射的导游会让你充分感受到关西人的开朗和热情。
49194	15	1	法善寺横丁
49194	16	1	上方浮世绘馆
49194	17	1	财神爷摩天轮
13200	2	1	位于大阪城中央的天守阁是大阪城的核心建筑，始建于1583年，因此它又被称为“秀吉的城”。如今的天守阁是1931年仿造的混凝土式建筑，内部已改造为关于丰臣秀吉及大阪城历史的博物馆，在顶层还可以眺望大阪市景。 建造在高台上的天守阁，白色的墙面配以绿色的屋瓦，每个飞翘的屋檐末端都装饰着用金箔塑造的老虎和龙头鱼身的金鯱造型，可谓金碧辉煌。每到春秋两季，樱花盛开或枫叶染红，便是这里最美丽的时候。
13200	3	1	大阪城
13200	5	1	楼层指南 走进天守阁内，第1层有一个小剧场，依次放映5部关于丰臣秀吉和大阪城的节目，并配有中文字幕，你不妨坐下来观看一番。 第2层主要是介绍大阪城及日本城堡的基础知识，这里还有试穿头盔、阵羽织及和服的体验活动，可以让你扮一回战国枭雄来拍照留念，每次收费300日元。另外，天守阁中唯一的厕所也位于第2层。 第3、4层主要展示丰臣秀吉及战国时代的重要史料，藏品每两个月会更换一次；你还会看到不同时期大阪城的复原模型，可以很直观地了解其布局结构及演变情况。需注意这两层是禁止拍照的。 在第5层，有讲述“大阪夏季之战”的屏风图及微缩模型，活灵活现的人物阵队展现出激战时的情景；还有一块影视宽屏，图解屏风图上所描绘的各个场面的故事情节。 第6层是回廊，游客不能入内。第7层有通过19个场面的透视画介绍丰臣秀吉一生的“布景太阁记”，高科技影像将丰臣秀吉的形象打造得栩栩如生。 最后来到第8层的展望台，从离地面50米的高处俯瞰气势雄伟、风景秀丽的大阪城，还能眺望大阪市区的街景，现代化的高层建筑、大阪平原、远处耸立的山脉等风光尽收眼底。
46367	1	1	梅田是大阪市北部地区的经济中心，这里有超大型的综合枢纽车站梅田-大阪站，JR线、阪急线、阪神线和三条地铁线在这里交汇。车站周围，百货公司数量众多，摩天大楼高耸林立，是公司、银行、饭店等云集之地。
46367	2	1	与以难波、心斋桥为中心的“南”相对应，梅田被称为“北”，终日人流不断，是一个非常繁华的大商业区。在以日本规模最大地下街自居的梅田地下街，咖啡馆、餐厅以及经销洋货、杂货、食品的店家鳞次栉比，彩色磁砖铺地，有着美丽喷泉的“泉水广场”一带俨然已成了人们休闲的最佳去处。此外还有TOHO电影院、四季剧场等设施，可以选择看一场日本电影或是观赏一场演出。
46367	3	1	登上大阪站附近的梅田蓝天大厦，在40层高的空中庭园展望台上远眺大阪市景，特别是当夜幕来临，俯瞰脚下的万家灯火，十分美丽。
46367	4	1	梅田蓝天大厦
46367	5	1	空中庭园展望台
46367	6	1	漆成红色，十分引人瞩目的Hep Five摩天轮则是梅田另一地标性景点。很多情侣都喜欢搭乘摩天轮坐上一周，享受空中15分钟的浪漫。
13131	1	1	清水寺始建于778年，是京都较为古老的寺院之一，后于1994年被列入世界文化遗产名录。本堂前悬空的清水舞台是日本的珍贵文物，四周绿树环抱，春季时樱花烂漫，是京都的赏樱名所之一，秋季时又化身为赏枫圣地，红枫飒爽，无比壮丽。
13131	2	1	清水寺始建于
13131	3	1	778
13131	4	1	年，是京都较为古老的寺院之一，后于
13131	5	1	1994
13131	10	1	来到音羽山下，沿着小道步行上山。进入清水寺境内，会经过仁王门、西门、三重塔、随求堂、开山堂等建筑，能看到仁王像、地藏佛等雕刻。寺内有很多游客在点香、求签，香火很旺。此外，游客还可以进入随求堂的地下室，体验有名的
13131	11	1	“
13131	12	1	胎内漫步
13131	13	1	”
13131	14	1	，寓意在菩萨体内祈祷。
13131	17	1	继续向前到清水舞台下方，抬头仰望，可以清楚地看到这个用巨型榉木柱并排支撑的“悬造式”建筑，整个建筑没有使用一枚钉子，非常壮观。从旁边的木质台阶走上舞台，可以眺望山下京都的风景，非常古朴，几乎看不到什么高楼大厦。本堂正殿供奉的本尊是十一面千手观音立像。
13131	18	1	继续向前到清水舞台下方，抬头仰望，可以清楚地看到这个用巨型榉木柱并排支撑的
13131	19	1	“
13131	20	1	悬造式
13131	21	1	”
13131	22	1	建筑，整个建筑没有使用一枚钉子，非常壮观。从旁边的木质台阶走上舞台，可以眺望山下京都的风景，非常古朴，几乎看不到什么高楼大厦。本堂正殿供奉的本尊是十一面千手观音立像。
13131	25	1	奥之院 本堂斜对角是奥之院，这里有个观景台，能看到突出在悬崖之上的清水舞台全景，可以拍到舞台的经典角度。奥之院是清水寺的本源，比本堂小，供奉着千手观音、毗沙门天、地蔵菩萨、风神雷神等，但与本堂的本尊有所不同。
13131	27	1	奥之院
13131	31	1	本堂斜对角是奥之院，这里有个观景台，能看到突出在悬崖之上的清水舞台全景，可以拍到舞台的经典角度。奥之院是清水寺的本源，比本堂小，供奉着千手观音、毗沙门天、地蔵菩萨、风神雷神等，但与本堂的本尊有所不同。
13131	34	1	音羽之瀑 出了奧之院，沿山路下山就会看到“音羽之瀑”，是清水寺名字的由来，其三个源流分别代表着健康、学业和姻缘，很多人在这里排队接水饮用、祈福。你可以祈求健康长寿、学业有成或是爱情顺利。
13131	36	1	音羽之瀑
13131	39	1	出了奧之院，沿山路下山就会看到
13131	40	1	“
13131	41	1	音羽之瀑
13131	42	1	”
13131	43	1	，是清水寺名字的由来，其三个源流分别代表着健康、学业和姻缘，很多人在这里排队接水饮用、祈福。你可以祈求健康长寿、学业有成或是爱情顺利。
13131	46	1	地主神社 在本堂的北边还有一个地主神社，是祈求爱情、缘分之地。神社前有两块相距十来米的石头，据说蒙上双眼从一头走到另一头去摸对面的石头，就能得到真爱。难度有点大，所以很多人会自己闭着眼睛让同伴引导着自己去摸石头。
13131	48	1	地主神社
13131	51	1	在本堂的北边还有一个
13131	52	1	地主神社
13131	53	1	地主神社
13131	54	1	地主神社
13131	55	1	，是祈求爱情、缘分之地。神社前有两块相距十来米的石头，据说蒙上双眼从一头走到另一头去摸对面的石头，就能得到真爱。难度有点大，所以很多人会自己闭着眼睛让同伴引导着自己去摸石头。
13131	58	1	此外，寺内还有很多建筑值得细细观赏。每年在特定时间会开放夜间参拜，在灯光照耀下的清水寺显得格外漂亮。这里经常会有庆典活动，例如秋季红叶灯饰特别庆典等，用以表现当年的世态和人们的感受，很有意思。
13131	59	1	此外，寺内还有很多建筑值得细细观赏。每年在特定时间会开放夜间参拜，在灯光照耀下的清水寺显得格外漂亮。这里经常会有庆典活动，例如
13131	60	1	秋季红叶灯饰特别庆典等
13131	61	1	，用以表现当年的世态和人们的感受，很有意思。
13144	1	1	金阁寺本名是鹿苑寺，由于寺内核心建筑舍利殿的外墙全部贴以金箔装饰，故昵称为“金阁寺”。寺院始建于1397年，原为足利义满将军（即动画《聪明的一休》中利将军的原型）的山庄，后改为禅寺“菩提所”。
13144	2	1	据说以金阁为中心的庭园为“极乐净土”，与寺前的镜湖池相互辉映，尤其在晴天风景极好，而这也成为了京都的象征。
13144	3	1	春秋两季是金阁寺的旅游旺季，但实际上这里的景致一年四季皆有不同美貌，无论是深秋的似火红叶还是冬季的白雪银装，都映衬出金阁寺的别致，令人着迷。
13144	4	1	这座三层的楼阁每一层都有不同的建筑风格，虽然不能入内，但一楼正面的窗户通常是开着的，隔着池塘仔细望去应该可以看到释迦牟尼和足利的雕像。隔着池塘看过金阁寺后，向前走会经过总教士的前居所“北条”，但也不开放参观。走到金阁寺背面，可以近距离目睹金灿灿的墙面。寺后的庭园保留了“良光”时的原貌，庭园内还有其他的观景，如“决不干涸的”安眠泽，以及被游客投掷了很多硬币以祈福的小石像群。
13144	5	1	金阁寺还有一个独特的地方——游客拿到的门票是写有祝福的纸符，而在院中的不动堂旁边有中文和韩文的神签可供占卜。此外，你也可以在小茶室买些抹茶甜点来尝尝，味道很棒。
61258	1	1	岚山是京都市西郊的一处自然观光胜地，包括渡月桥两岸周边及嵯峨野地区。这里的樱花和红枫都非常有名，而风光秀美的嵯峨野竹林也流露着京都独特的韵味。此外，岚山一带还散布着许多知名的寺院、神社。
61258	2	1	标志性景观——渡月桥
61258	4	1	横跨桂川的渡月桥是岚山的标志性景观，保留着木造结构的桥身与背后树木繁茂的群山构成一幅美不胜收的山水画卷。桂川河岸旁的岚山公园（分为龟山、中之岛和临川寺三个部分）是一个人气休闲场所，公园内种植了大面积的樱花与枫林，每到樱花盛开及枫叶转红之时，景色尤为壮观，引来众多游客前来观赏。到了12月，这一带还有花灯会，届时街道上挂着灯笼，十分别致。在岚山公园（龟山地区）的半山腰上还能找到《雨中岚山》的纪念诗碑。
61258	5	1	寺院和神社
61258	6	1	寺院和神社
61258	7	1	岚山一带的寺院和神社很多，其中位于中心地带的天龙寺可以说是必逛的去处。天龙寺以其精致的造景庭园而闻名，并被喻为“京都五大禅寺”之首，很多人会到此祈求学业顺利。天龙寺的北边有一座野宫神社，据说祈求姻缘和多子顺产比较灵，那里还有在日本少见的黑色鸟居。
61258	8	1	嵯峨野竹林
61258	9	1	嵯峨野竹林
61258	10	1	在天龙寺北侧与野宫神社之间，有一条并不长的嵯峨野竹林，小径两旁长满了参天的“野宫竹”，是岚山地区人气很高的观光点。夏天在竹林中漫步，可以感受悠然意境和阵阵清风，而岚山花灯会时还会点亮灯光，在冬日中别有情趣。
61258	11	1	骑行游览
61258	12	1	骑行游览
61258	13	1	骑行是周游岚山及嵯峨野地区的好方式，骑着自行车穿梭在郊区的民居和寺院、神社之间，既省力又令人心情舒畅。祇王寺、大觉寺、常寂光寺、二尊院、化野念佛寺等都值得一游，你也可以前往山上的岩田山猴子公园，不仅会看到许多野生的猴子，还能鸟瞰一番京都美景。在岚山车站附近就能找到租自行车的店铺。
61258	14	1	火车游览
61258	15	1	火车游览
61258	16	1	乘坐嵯峨野观光小火车来游览岚山及保津峡风光是一件非常浪漫的事情，列车沿着保津峡上的铁道行驶，春天樱花簇拥、夏天潺潺溪流、秋天红叶舞落、冬天银白素雅，四季之景都令人回味。火车在Torokko嵯峨站（JR嵯峨岚山站旁）和Torokko龟冈站之间运行，往返的沿途景色有所不同。
61258	17	1	游船
61258	18	1	游船
61258	19	1	如果你时间充裕，还可以到龟冈去体验一回保津川漂流或游船，穿越如诗如画的乡间峡谷，并且经过几个湍急的段落，抵达岚山的渡月桥。
61258	20	1	美味料理
61258	21	1	美味料理
61258	22	1	在岚山也能吃到许多日式点心、烧烤等美味的料理，尤其在渡月桥附近的马场町及三条通比较集中，那里醒目的餐厅招牌、热情的服务人员让人倍感亲切。
110500	1	1	伏见稻荷大社是位于京都南边的一座神社，供奉着保佑商业繁荣、五谷丰收的农业之神稻荷，香客众多。这里最出名的要数神社主殿后面密集的朱红色“千本鸟居”，是京都代表性景观之一，也曾出现在电影《艺伎回忆录》中。
110500	2	1	从JR稻荷站出来往东走不久，就到了伏见稻荷大社的入口，这里矗立着由丰臣秀吉于1589年捐赠的大鸟居，后面便是神社的主殿及其他建筑物。在神社里，你会看到各式各样的狐狸石像，这是因为狐狸被视为神明稻荷的使者。
110500	3	1	在主殿旁的洗手处按照步骤指示图净手净心，然后到主殿去拍拍手、祈个愿吧，祈愿的主题最好是和财运及商业有关的。花上100日元可以求个签，你也可以买个绘马（祈愿牌）来写祝福的话。狐狸脸形的绘马是这里的一个特色，给小狐狸画上表情很有意思，而狐狸造型的御守（护身符）也是人气十足的手信；还有迷你鸟居造型的绘马，同样非常可爱。
110500	4	1	千本鸟居 逛完主建筑，绕到主殿后面就是千本鸟居的入口。成百上千座的朱红色鸟居构成了一条通往稻荷山山顶的通道，其间还有几十尊狐狸石像。探索千本鸟居的山间小径是大多数外国游客来到伏见稻荷大神社的主要目的，全程约4公里，步行到山顶来回大约需要2-3小时。
110500	7	1	走进千本鸟居，老朽褪色的暗红色牌坊和光鲜亮丽的朱红色牌坊密集地交织在一起，透过阳光的照射显得格外壮观迷人，视觉上相当震撼，吸引了许多喜爱摄影的朋友。沿途的鸟居是由个人或公司捐献的，在每个鸟居的背面可以看到捐赠者的姓名和捐赠的日期。根据鸟居的大小，捐赠的价钱也不等，最小的约20万日元，最大的超过100万日元。
110500	8	1	蜿蜒而上的千本鸟居并不是一条线直通山顶的，除了一眼望不到底的大鸟居通道，也有拆分为两条的小鸟居通道，每隔一段路还有不同的休息场所及供奉场所。
110500	9	1	走个30-45分钟左右，你会发现鸟居的数量就逐渐减少了。走到半山的四辻路口，可以俯瞰京都的景色，若是在晚上看夜景也很独特。从四辻路口到山顶的步行道为圆形路线，许多游客会在这里掉头下山，因为再往上走也没有太大的惊喜了。不过，如果你不辞辛劳坚持爬上山顶，会看到一个小神社，那里可以免费抽签。
13125	1	1	二条城建立于1603年，是当时的德川幕府将军在京都的住所，也是德川幕府的权力象征。这座城郭保存了日本桃山时代的绘画雕刻及建筑特色，是京都的世界文化遗产之一。每到樱花季，樱花竞相开放，引来如织的游人。
13125	2	1	二条城建立于
13125	3	1	1603
13125	4	1	年，是当时的德川幕府将军在京都的住所，也
13125	5	1	是德川幕府的权力象征。这座城郭保存了日本桃山时代的绘画雕刻及建筑特色，是京都的世界文化遗产之一。每到樱花季，樱花竞相开放，引来如织的游人。
13125	6	1	整座建筑由石墙及护城河包围着，总体上分为本丸御殿（主城）、二之丸御殿（次城）以及环绕两个御殿的庭园等区域。游客一般从东边的东大手门进入。
13125	7	1	整座建筑由石墙及护城河包围着，总体上分为本丸御殿（主城）、二之丸御殿（次城）以及环绕两个御殿的庭园等区域。游客一般从东边的东大手门进入。
13598	1	1	华尔街曾是美国各大金融机构的所在地，911后很多机构搬离此地，大部分改为住宅，不过这条摩天大楼林立的狭长小街依然是热门旅游地。
13598	2	1	参观路线：
13125	9	1	二之丸御殿 从大门往里走，穿过中国式唐门便到了二之丸御殿。殿内有将军接待各位官员宾客的房间和生活起居室等，地上铺着榻榻米坐垫，并以精致的隔扇画和雕刻作为装饰，凝聚了当时建筑艺术的精华之美，是日本国宝。据说当时只有贵宾才能一路进入将军所在的房间，两旁的壁橱内还隐藏着保镖，而普通宾客只能坐在相邻的房间，无法直接看到将军。
13125	11	1	二之丸御殿
13125	14	1	从大门往里走，穿过中国式唐门便到了二之丸御殿。殿内有将军接待各位官员宾客的房间和生活起居室等，地上铺着榻榻米坐垫，并以精致的隔扇画和雕刻作为装饰，凝聚了当时建筑艺术的精华之美，是日本国宝。据说当时只有贵宾才能一路进入将军所在的房间，两旁的壁橱内还隐藏着保镖，而普通宾客只能坐在相邻的房间，无法直接看到将军。
13125	16	1	莺声地板 二之丸御殿内连接各个房间的走廊地板非常出名，其独特之处是，当你行走其上，地板便会发出夜莺啼叫一般的声响，因此被称为“莺声地板”。如此的设计并非为了诗情画意，而是工匠建造时故意为之，适当留出了木板和木榫之间的松动，以防夜间刺客入侵。
13125	18	1	莺声地板
13125	21	1	二之丸御殿内连接各个房间的走廊地板非常出名，其独特之处是，当你行走其上，地板便会发出夜莺啼叫一般的声响，因此被称为
13125	22	1	“
13125	23	1	莺声地板
13125	24	1	”
13125	25	1	。如此的设计并非为了诗情画意，而是工匠建造时故意为之，适当留出了木板和木榫之间的松动，以防夜间刺客入侵。
13125	27	1	二之丸庭园 御殿外有二之丸庭园，这个传统的日本庭园中有大池塘、观赏石和修剪整齐的松树等景观，漫步其间很有意境。
13125	29	1	二之丸庭园
13125	32	1	御殿外有二之丸庭园，这个传统的日本庭园中有大池塘、观赏石和修剪整齐的松树等景观，漫步其间很有意境。
13125	34	1	本丸御殿 本丸位于二之丸的西面，曾在18世纪时被焚毁，如今的建筑物是从桂离宫移过来的。
13125	36	1	本丸御殿
13125	39	1	本丸位于二之丸的西面，曾在
13125	40	1	18
13125	41	1	世纪时被焚毁，如今的建筑物是从
13125	42	1	桂离宫
13125	43	1	桂离宫
13125	44	1	桂离宫
13125	45	1	移过来的。
13125	47	1	可赏樱花和枫叶的绿林道 除了优美的建筑本身，城内还环绕着成荫的绿林道，种植了各种樱花树，包括不少迟开的品种。
13125	49	1	可赏樱花和枫叶的绿林道
13125	52	1	除了优美的建筑本身，城内还环绕着成荫的绿林道，种植了各种樱花树，包括不少迟开的品种。
13125	56	1	二条城还有着绚丽的秋色，这里的枫叶和银杏非常漂亮。此外，一半日式、一半西式的清流园也同样值得游览一番。
13125	57	1	二条城还有着绚丽的秋色，这里的枫叶和银杏非常漂亮。此外，一半日式、一半西式的清流园也同样值得游览一番。
110499	1	1	日本全国约有3000多座八坂神社，而位于京都祇园的是八坂神社的总本社，也被称为祇园神社，是京都香火最旺的神社之一。这里每年7月都会举行热闹非凡的祇园祭，与东京的神田祭、大阪的天神祭并称为“日本三大祭”。
110499	2	1	祇园
110499	3	1	神社入口 八坂神社有好几个入口，如果你从四条通前往，过了东大路通便是神社的西楼门，朱红的色调十分亮眼。若是绕到南楼门外，还会看到一座巨大的石造鸟居。进门后可以先到旁边的“手水舍”去入乡随俗洗个手。
110499	6	1	舞殿 来到神社中央的本殿前，有一座舞殿，是举行祭祀的舞台。你会注意到舞殿的四周都挂满了提灯，上面写着不同赞助商的名称，保佑他们生意兴隆。每当夜幕降临，这些提灯会被点亮，将舞殿点缀得特别华美。
110499	9	1	黄昏时欣赏落日 要是正好在黄昏前来到八坂神社，你不仅能欣赏到落日余晖洒在朱漆大门上的美景，等到天黑后，还能感受灯光映照下宁静而耀眼的别样氛围。
110499	12	1	美御前社 在八坂神社内四处转转，还会看到名目繁多的各种小神社。其中，有一座美御前社，供奉着掌管美貌的神，吸引了不少爱美的女孩子来祈福。美御前社旁有一处美容水，你也不妨洗洗脸和手、许个愿吧。
110499	15	1	求签的好地方 八坂神社里有专门求签、写绘马和请御守的地方。这里的绘马图案非常多样，而祈求恋爱的心形绘马也是十分受欢迎的，都是500日元一枚。
110499	18	1	祇园祭 每年7月的祇园祭是八坂神社最热闹的时候，届时神社外的四条通会实行交通管制，人山人海的游客和本地人会步行到此，而神社内就像美食节一般，可以品尝到各式各样的日本小吃，还有许多吸引眼球的节庆装饰。
13592	1	1	自由女神像是1876年法国赠送给美国独立100周年的礼物，被誉为美国的象征。自由女神穿着古希腊风格的服装，头戴光芒四射的冠冕，七道尖芒象征世界七大洲，右手高举象征自由的火炬，长达12米。特别是在夜晚灯光照耀下显得更加神圣。
13592	2	1	轮渡路线
13592	4	1	从炮台公园出发：Battery Park——Liberty Island——Ellis Island——Battery Park
13592	5	1	从自由州立公园出发：Liberty State Park——Ellis Island——Liberty Island——Liberty State Park
13592	6	1	（由于两条航线在自由岛登陆的码头不同，建议记住登岛时的码头位置，以免返程时去错码头上错游船。）
13590	1	1	中央公园坐落在高楼林立的曼哈顿中心，面积达340万平方米，园内步行道总长93公里，是纽约这座繁华都市中一片静谧休闲之地。园内分布着大大小小的湖和森林，设有动物园、运动场所及游乐设施，花上一整天也逛不完。
13590	2	1	推荐路线和景点
13590	4	1	1. 园内有两个大湖，稍大的是Reservoir，小的是The Lake，两处大草坪包括位于两湖之间的Great Lawn和位于The Lake南面的绵羊草地。
13590	5	1	2. 公园西南角入口是著名的哥伦布圆环；公园的东南角入口是Grand Army Plaza，这里可以乘坐观光马车游览，半小时100美元左右。
13590	6	1	3. 东南角的Wollman Ice Skating Rink，冬天是溜冰场，夏天则是小型娱乐场。向北是动物园，主要展示热带雨林、北极圈、加利福尼亚州这三种气候带的动物。
13590	7	1	4. 公园中部最出名的景点是湖边的Bethesda Terrace和毕士达喷泉，湖的西侧是永远的草莓地，约翰列侬的遗孀为了纪念亡夫而买下了这个泪滴形状的山头，现已成为很多乐迷的圣地，经常有人来此献花，每年列侬忌日时还会有大型纪念活动。
13590	8	1	5. 公园接近正中央的位置是Belvedere Castle，这里是公园的最高点，是个登高远眺的好地方。
13590	9	1	6. 公园北部以大片的草坪树林为主，相对南部显得更为清净惬意，游人较少。
13645	1	1	总高度达444米的帝国大厦矗立于纽约市内的曼哈顿岛，是纽约乃至整个美国的标志和象征。作为纽约的地标性建筑，帝国大厦以其独特的景观而闻名，游客站在86层和102层的观景台上可以看到曼哈顿的地平线，领略纽约城360度的美景，一直以来都是世界各国游客所向往的旅游胜地。 86层观景台：
13645	5	1	室内及室外观景台，位于86层，距地面高度1,050英尺(320米)，可选八种语言包括普通话在内的语音导览器。这是纽约最高的露天观景台。参观帝国大厦的86楼露天观景台，感受置身世界中心和世界之巅的快感。作为全世界最著名的观景台，86楼观景台一直被作为众多电影和电视剧，以及不计其数的私人留影的背景。观景台以大厦的尖顶为中心，提供纽约和更广阔地区的360度全景。从这里您将欣赏到独一无二的中央公园、哈德逊河和东河、布鲁克林大桥、时代广场、自由女神像等景观。我们的多媒体手持式设备可从各个方向指导您的观景。还可利用我们的高性能双筒望远镜获得更清晰的视野。
13645	6	1	102层观景台
13645	9	1	室内观景台，位于102层，距地面高度1,250英尺(381米)。 2016年，为提供游客详尽的展览解说和全方位的美景，带领游客领略这所建筑近百年的历史，帝国大厦观景台正式推出其全新的移动端导览APP，并且提供免费WIFI供游客下载。该导览器分为中英文两种版本，旨在让全世界的游客根据自己的语言需求进行下载以及获悉更多的内容介绍。中国游客可在Apple Store中直接搜索“帝国大厦”即可得到中文版本，安卓系统用户也可在境外通过Google Play下载，该导览器都可提供标准普通话的语音讲解服务。
13645	14	1	游客参观帝国大厦时，多媒体设备会通过音频和视频引导他们领略四个区域：“节能改造”展厅、“敢于梦想”展厅、并最终导向帝国大厦著名的86层观景台与102层观景台。系统应用兼备了趣味性和知识性，游客除了能在设备上欣赏关于帝国大厦的视频和图片外，还可以参加帝国大厦知识小问答活动，不仅如此，为方便从帝国大厦观景台俯瞰市区其他景点的游客更全面了解纽约，导览器还设定了纽约市著名景点的详细信息介绍。相信通过如此便捷的多媒体体验，游客会对帝国大厦的建筑、历史、及其不可撼动的国际地位有更加深刻的理解。还在犹豫什么，赶快来帝国大厦观景台体验吧！
13874	1	1	时代广场是纽约的地标，第七大道与百老汇大道交汇形成的这一片三角地带，高楼耸立、店铺云集，附近聚集了近40家商场和剧院。夜幕降临后大量五光十色的霓虹灯招牌和LED屏幕开启，灯火通明，每个屏幕都播放着世界各地的广告和宣传片。
13874	2	1	这里不分白昼，都有来自世界各地的游客前来参观，街道上游人如织，各国语言穿插其中，随处可见的街头表演更是热闹非凡。
13874	3	1	每年的新年倒计时，是时代广场最为热闹的时刻，从下午开始就要排队入场，到新年来到的那一刻，来自世界各地的游客都将一起欢呼庆祝，绝对是一场难忘的回忆。
13591	1	1	大都会艺术博物馆建于1870年，位于环境优美的中央公园旁，与大英博物馆、卢浮宫并称世界三大博物馆。博物馆共四层，馆藏多达330万件，涵盖埃及、希腊、罗马、欧洲、亚洲等地的各类珍贵文物和艺术品。
13591	2	1	埃及展厅
13591	4	1	位于一楼，这里的看点就是从埃及整体迁移过来的顿都神庙（The Temple of Dendur）。
13591	5	1	雷曼收藏馆
13591	7	1	位于一楼，是独立的圆形展馆，这里收藏了14-20世纪欧洲的绘画和各类装饰品，十分精美。
13591	8	1	中国展厅
13591	10	1	位于二楼，除了各时期的瓷器外，一比一仿造的苏州园林让人宛如置身苏州。
13598	4	1	顺着华尔街门牌号一路向东步行，华尔街1号是纽约银行大楼（原欧文信托银行大楼）。11号是纽约证券交易所，14号是美国信孚银行大楼，而华尔街23号原先是摩根大通大楼，现在已改为了公寓。
13598	5	1	继续向东步行至华尔街37号，这里原先是美国信托公司、美国大通银行，而现在也改为出租的住宅。在向前的华尔街40号是川普大楼、曼哈顿信托银行。华尔街45号则是原先的多伦多道明银行，现在也改为住宅。
13598	6	1	而华尔街48号，原先是纽约银行总部，现在成为了美国金融博物馆。华尔街60号则是德意志银行大楼/摩根大通大楼。华尔街63号原先是布朗兄弟哈里曼信托大楼，现在也改为了住宅。最后的华尔街111号则是花旗银行大楼。
13607	1	1	悉尼歌剧院是悉尼最容易被认出的建筑，它白色的外表，建在海港上的贝壳般的雕塑体，多年来一直令人们叹为观止。
13607	2	1	1. 外形系三组巨大的贝壳 歌剧院位于澳大利亚新南威尔士州的首府悉尼市贝尼朗岬角，三面临水，环境开阔。歌剧院耸立在钢筋混凝土结构的基座上，最高的贝壳有20层楼那么高。外观十分的漂亮，既像飘浮在空中的散开的花瓣，又像三组巨大的贝壳片。 第一组贝壳片在地段西侧，四对壳片成串排列，三对朝北，一对朝南，内部是剧院最大的音乐厅和戏剧院。 第二组贝壳在地段东侧，与第一组大致平行，形式相同而规模略小，里面主要是琼·萨瑟兰剧院。 第三组贝壳在它们的西南方，规模最小，由两对壳片组成，里面都是一些餐厅和酒吧。其他剧场、工作室、录音室、购物店等也都巧妙地布置在基座内。
13607	8	1	2. 全世界最大的表演艺术中心之一 歌剧院规模宏大，陈设讲究，演出频繁，每年在悉尼歌剧院举行的表演大约3000场，是全世界最大的表演艺术中心之一。欲在悉尼歌剧院欣赏表演者，既可到歌剧院一楼门厅的售票窗口选剧买票，也可在网上提前购买。 网上买的好处是可以自己随心所欲选座位，会有很清楚的图示告诉你坐在哪。售票窗口当然也可以选座位，就是容不得你太磨蹭还要英文沟通。另外很多热门剧目提前半个月、一个月票就售完了，现场买可能买不到票。 另外，据说第六排中间的位置是整个音乐厅音乐效果最好的位置。
13607	13	1	3. 品尝各地的美食 在悉尼歌剧院你不仅可以观看最棒的演出，还可以一边欣赏美丽的风景，一边品尝各地的美食。这里不仅有经营越南菜的Misschu餐厅、日系餐厅Kenji，更有可以欣赏海边的风景的Opera Bar。 当然这里还有一些比较平价的小餐厅，如果你不是选择很贵的菜，一般的套餐在10-20澳元就能吃饱。
13607	19	1	4. 可购商品范围非常广泛 悉尼歌剧院提供的商品范围非常广泛，包括悉尼歌剧院模型、演出相关纪念品及新锐设计师作品等。
15861	1	1	达令港（又名情人港）位于澳大利亚新南威尔士州悉尼，是当地集娱乐餐饮和购物于一体的大型休闲区。港口昼夜不分，景色各异，你可以坐在码头边上吹吹海风，欣赏港口两岸的风景。
15861	2	1	1. 周边景点 达令港内由港口码头、绿地流水和各种建筑群组成。国王街码头是最热门的地点之一，遍布时尚的餐饮场所。这里更有悉尼水族馆、悉尼野生动物园、悉尼杜莎夫人蜡像馆等知名景点。 你也可以选择在岸边的户外区就餐，在港口购物中心购物，或者聆听户外表演者的演出，亦或与小鸽子互动一下。当然你还可以参加从达令港出发的游船游览团，更近距离的欣赏这里的美景。
15861	6	1	2. 餐饮娱乐 港口东面的海扇湾的一边则全是户外咖啡馆、酒吧和餐馆，这里是当地人休闲时间经常去的地方。达令港西面的港口购物中心（Harbourside Shopping Centre）则集购物和餐饮美食于一体，从服装到澳洲工艺品都可以在这里买到。 另外，澳大利亚国立海洋博物馆也在这里。达令港附近还有世界上最大的IMAX电影院、动力博物馆、为纪念悉尼奥运会建造的一座具有中国古典园林风格的谊园，如果有兴趣你都可以去参观看看。拥有着超浪漫名字的达令港，如传说中一样，天空中都弥漫着爱的气息。
15861	10	1	3. 烟火表演 达令港区内设施于1988年落成，是为了纪念欧洲移民到达澳洲200周年而建。悉尼的居民在特别的节日如圣诞节、新年除夕及国庆日都喜欢走到达令港庆祝一番，届时还能看到绚丽的烟火表演。 此外，达令港每月都有不定期的组织一些文艺演出、艺术活动等。欲了解更多详情请查看官网：http://www.darlingharbour.com/whats-on.aspx
15861	14	1	http://www.darlingharbour.com/whats-on.aspx
13604	1	1	悉尼海港大桥（Sydney Harbour Bridge）位于悉尼歌剧院的西边，是悉尼的标志性桥梁，也是地标性建筑，与悉尼歌剧院齐名，占据了悉尼明信片的绝大多数版面，连接着悉尼CBD中心和北岸。
13604	2	1	1. 海港大桥概况 海港大桥建于1932年，总长1149米，宽度139米，最高503米，是世界上最高的钢铁拱桥。现在攀爬悉尼大桥（Bridge Climb）已经成为悉尼最受欢迎的旅游项目，这也是世界上唯一允许游客爬到拱桥顶端的大桥。
13604	5	1	2. 多种体验方式 体验悉尼海港大桥有多种途径，可以从桥下驾车而过、攀爬桥梁、乘坐火车穿过桥身或者从桥下扬帆而过，然而全方面体验大桥的最好途径是步行。你可在两岸通过楼梯登上桥。人行道在东边，自行车道在西边。你可以登上东南部的塔楼进入塔楼瞭望台，或是通过攀登大桥来感受大桥巨大的拱形架。
13604	8	1	3. 攀爬海港大桥 攀爬海港大桥是游悉尼最经典的项目之一，迄今为止已经有超过三百万人穿着统一的蓝色服装攀爬海港大桥，无论是清晨、白天、黄昏还是夜晚，都可以爬上这座铁架桥，全方位的欣赏悉尼的市景。 爬上去之后，还能获得一张免费的合影和一张证书，不过爬海港大桥价格比较高，最便宜的都要100多澳币，所以中国人的比例很低，但是爬上地标的体验和成就感是无与伦比的，推荐一试。攀爬海港大桥有多种方式，具体可参加官网：http://www.bridgeclimb.com/
13604	12	1	http://www.bridgeclimb.com/
13604	13	1	4. 国庆日烟火表演 每年的新年（1月1日）和澳大利亚国庆日（1月26日），海港大桥都会有多次烟火表演，几乎所有的悉尼市民都会来观看这美丽的景象。
13604	16	1	5. 最佳拍摄地点 拍摄海港大桥，最佳地点是悉尼歌剧院和麦考利夫人座椅。悉尼歌剧院可以拍到海港大桥的全景，麦考利夫人座椅可以拍到悉尼歌剧院、海港大桥的合影。
15869	1	1	海德公园位于悉尼市中心，是一块闹中取静的长方形绿地，周围高楼林立，与圣玛丽大教堂仅有一条马路之隔。园内各处分布着雕塑、喷泉、池塘、小湖，有大片洁净的草坪，也有百年以上的参天大树，是休闲的一个好去处。
15869	2	1	1. 历史悠久 海德公园历史悠久，是悉尼最古老的一个城市公园。公园被东西走向的大道分为南、北两部分。位于公园的最北端，临着阿尔伯特王子路（Prince Albert Road）是为了纪念澳大利亚著名政治家William Bede Dalley 而建的一座人像雕塑。 公园中还立着一个方尖碑，其实只是个排气口，却仿照了伦敦的埃及方尖碑。库克船长的雕塑是公园内最高的建筑物，位于学院路与公园的交叉口。
15869	6	1	2. 公园内景 公园里绿树成荫，中间的一条林荫大道直通喷水池。亚奇伯德喷泉是由报业创始人出资建造，为了纪念一战中法国和澳大利亚联盟军。喷泉是依照太阳神波罗建造，阿波罗被骏马和乌龟雕塑围绕。阿波罗伸出的手遥指大教堂，身后围绕着三组希腊神话的里的神像，水池里还有几组铜雕。喷泉正对着圣玛丽大教堂，晴天时从这里看大教堂，有种无与伦比的美丽。 往南可以看到一个花园（Sandringham Garden），10月-12月这里花团锦簇、欣欣向荣。花园是为了纪念乔治五世与乔治六世而建。1954年英国女王第一次来澳洲，这个公园正式开放，并且以皇室在英格兰的官邸名字命名。 穿过马路，就来到了海德公园的南半部分，这里主要的建筑是澳新军团纪念馆和反思池，纪念馆不大，顶部是红色大理石制成的金字塔。公园的东南角，有一座长约1英寸的舰炮，这是一战时从在科科斯群岛附近沉没的德国巡洋舰上获得的战利品，也吸引了一批军事爱好者前来。
15869	11	1	3. 市民集会的重要地点 海德公园是很多悉尼市内徒步线路的起点，从这里向西则到达悉尼CBD，向北走是环形码头、悉尼皇家植物园和悉尼歌剧院，向东走是国王十字区以及热闹的老街区。公园就像是离开喧嚣城市的避风港。树荫下有提供休息的座椅，很多人来这里野餐和吃中饭，周末也有人踢球、散步、晒太阳，街头艺术表演、演说不绝于耳。 澳大利亚政府曾经发起“负责任的政府”运动，海德公园也因此而演变成为集会地点，人们可以在此自由地公开谈论政治。如今，公园依旧是市民集会的重要地点，这里时常会举办各种节日，比如悉尼美食节、土著文化庆典和流行音乐会等。
13616	1	1	悉尼的皇家植物园坐落在市中心，位于悉尼歌剧院的南部，相距约一千米，步行可到。在植物园可以眺望远处的悉尼海港大桥和悉尼歌剧院，这样的组合构成了悉尼最知名的景色之一，是拍摄悉尼标志性照片的最佳摄影点。
13616	2	1	1. 麦考瑞夫人的椅子 沿着园内东侧的伊丽莎白女王通道（Queen Elizabeth Walk）可以直接通往麦考瑞夫人岬角（Mrs. Macquarie's Point），这里的平台被称作“麦考瑞夫人的椅子”，那些经常出现在旅游书里面的前景为歌剧院，背景为悉尼海港大桥的经典照片，就是从这个角度拍摄出来的。除了麦考瑞夫人的椅子是很好的拍照点以外，植物园内的玫瑰花圃，蓝樱花、栀子花等非常丰富，随便拍都很美。
13616	5	1	2. 悉尼热带中心 植物园的南部是标志性建筑——悉尼热带中心（The Sydney Tropical Centre），外部超现代化的玻璃屋与卢浮宫竟然有些异曲同工之妙。植物园内的具体分布与路线可以参考官网：https://www.rbgsyd.nsw.gov.au/Visit/Map
13616	8	1	https://www.rbgsyd.nsw.gov.au/Visit/Map
13616	11	1	3. 新南威尔士州议会厅和州立图书馆 从植物园的南门出来，马路对面就是新南威尔士州议会厅和州立图书馆，建筑恢弘大气，适合摄影。
13619	1	1	岩石区是悉尼的发源地，坐落在繁华的海港湾内，岩石区陡峭的街道一直延伸到悉尼海港大桥，是悉尼最受欢迎的地方之一，历史与现代在这片土地上完美交融，呈现独一无二的风情。
13619	2	1	1. 欧洲风格建筑群 岩石区保留着殖民时期的建筑，但是大多已经被改装成了时尚店铺、特色餐厅和酒吧。世界各地特别是欧洲来的游客，无不以到岩石区观光为乐事，也许这是一种怀旧情结所致。岩石区虽然是一片很小的街区，但它的建筑群保留了欧洲的风格，众多的酒吧、餐馆、工艺品商店、艺术馆都弥漫着英格兰移民时期的怀旧氛围。你可以随便坐一辆公交到达环形码头，然后步行到达岩石区。
13619	5	1	2. 岩石集市 每个周末，岩石区就变成了人潮涌动的步行街，因为岩石集市就在这里举行着。这里有近200个摊位，出售珠宝、玩具、手工艺制品，当然还有各种美食，是悉尼最繁忙的集市之一。每周末集市的开放时间是10:00-17:00，位置在乔治街与Jack Mundey Place附近。每周五还有美食集市，开放时间是9:00-15:00，具体位置也在Jack Mundey Place。
13619	8	1	3. 幽灵之旅 岩石区虽然范围不大，体验活动却不少。如果你想深入了解悉尼早期历史黑暗的一面，那就参加环绕岩石区的幽灵之旅，走过以提灯照亮的小巷，聆听那些传说中的故事,具体可查看官网：http://www.ghosttours.com.au
13619	11	1	http://www.ghosttours.com.au
13619	12	1	4. 租车 你也可以租一辆自行车，租车公司会为你提供各种景点信息和地图。如果参加经典游，导游会骑着车带你来到悉尼的20多个知名景点，整个骑行的时间约4小时，可以直接网上预订：http://www.bonzabiketours.com/sydney/tours.php?code=SYD_CLASSIC。如果只想租车自己游览也可以，你可以直接发邮件预订或者网上预定，邮箱：info@BonzaBikeTours.com
13619	15	1	http://www.bonzabiketours.com/sydney/tours.php?code=SYD_CLASSIC
13619	16	1	info@BonzaBikeTours.com
13619	17	1	5. 酒吧 全悉尼最古老的酒吧Lord Nelson就在岩石区，位于19 Kent St，这里也是悉尼最古老的旅馆。
110165	1	1	十二门徒岩，位于大洋路上的坎贝尔港国家公园内，是大洋路上的知名景点，每年吸引着大量游客前往。
110165	2	1	1. 十二门徒岩的由来 十二门徒岩其实就是矗立在海中的岩石，起初是海岸线的一部分，经过海浪和大风的侵蚀，逐渐脱离开来。因为这十二根石柱让人联想到圣经中追随耶稣基督的十二使徒， 故得名“十二门徒”。由于海浪的持续冲积作用，现在只剩下了七座。
110165	5	1	2. 吉布森阶梯 在去往十二使徒的路上有一个知名的台阶，叫做吉布森阶梯（Gibson Steps），它从悬崖上开凿开来，台阶百米长，共有86级，来回约15 分钟。台阶通往沙滩，不过这里海浪湍急，不适合游泳，却适合垂钓。台阶宽度约1米左右，仅够一个人通过，因此行动不便的游客不要轻易尝试。走至尽头，便可眺望一望无际的碧蓝大海，以及两个巨大的石柱。台阶距离岩石约2分钟车程，附近就有停车场，停车非常方便，游客可以下车后从十二门徒停车场通过碎石步游道到达吉布森阶梯。
110165	8	1	拍摄十二门徒岩较好的时间是清晨和黄昏，乘坐直升机俯瞰的话则更为震撼，另外在这里还可以参加海钓、高尔夫、水上运动等项目。
110165	9	1	3. 伦敦桥和拱门 十二门徒岩虽然是大洋路的亮点，但大洋路沿线还有很多可以玩的地方，伦敦桥和拱门等景点都相距不远，可以一并游览。拱门适合于午后观赏，此时这一美景沐浴在一片温暖的金色阳光之中。 共同位于坎贝尔港国家公园的还有沉船海岸和拉卡德大峡谷，距离十二门徒岩只有10分钟的车程，由于这块区域地势险峻海浪湍急，这里曾发生过大大小小多起沉船事故。这里的沙质柔软，景色壮观，适合摄影。 拱门岛也在附近，不过2009年就已经轰然倒塌，足见海岸线的脆弱。
45087	1	1	联邦广场是被国内外游客持续评为两大顶级景点之一，同时也是墨尔本市及当地人民的全新市政和文化中心。它是一个连通社区、分享文化和表现特色的理想之所，展示了墨尔本和维多利亚州的生活风貌。
45087	2	1	1. 澳大利亚活动影像中心可以欣赏早期电影片段以及高画质的电影 正对着弗林德斯大街的就是澳大利亚活动影像中心，这里收藏了各种活动影像的资料，包括电影、电视和数码文化，在这里可以欣赏到珍贵得让人难以忘记的早期电影片段，著名的电影节也会在这里举办，可以与知名导演面对面。
45087	5	1	2. 世界上第一个完全收藏澳大利亚艺术品的大型艺术馆 联邦广场近60%到访的是当地人（市中心和都市区居民），为纪念澳大利亚各州共同成立澳大利亚联邦100周年而建。紧挨着的是伊恩·波特中心，是世界上第一个完全收藏澳大利亚艺术品的大型艺术馆，它拥有二十多个展厅，收藏了土著人和托雷斯海峡岛民的艺术、摄影、绘画、编织以及装饰艺术品，门票免费，不过一些特别展览可能会收费。 值得注意的是，馆内有讲解员志愿者，每天在固定时间为观众介绍各个展览的情况，游客可以在一楼大厅集合。
45087	9	1	3. NGV儿童游戏区为儿童和他们的家庭提供的活动区域 NGV儿童游戏区是为儿童和他们的家庭提供的活动区域，他们可以在这里从事创造性的安装活动和其它一些专门为他们设计的活动，门票免费。具体的活动内容可以参考官网。
45087	12	1	4. 拥有这么多家风味独特并可满足不同消费层次的美食 墨尔本人喜爱当地食物并享受着世界不同的美食，而联邦广场正是拥有这么多家风味独特并可满足不同消费层次的场所，你永远不用担心喝不到咖啡，广场内咖啡馆遍地都是，且味道纯正。 世界风味的美食也在不断挑战你的胃，澳洲菜、中国菜、日本料理、意大利菜等等应有尽有，有选择困难的游客可要做好准备了。
45087	16	1	5. 纪念品店也能满足购物需求 从玻璃艺术店到澳洲纪念品，书籍和玩具，联邦广场拥有一系列独特的礼品店，这是你可以为你的家人和朋友买点礼物的好地方。
110407	1	1	唐人街两旁几乎全部是中国的餐馆和食品杂货商店，放眼望去几乎都是中文招牌，当地人不仅到这里来享受中国的美食，还可以就便观赏中国的文化艺术，每年春节是这里最热闹的时候，狮子舞、耍龙灯等都是这里的传统节目。
110407	2	1	1. 融合古老与现代 墨尔本的唐人街相邻市中心最繁华的斯旺斯顿大街商业步行街（Swanston Street Walk），主街是小伯克利街（Little Bourke Street）。唐人街是一条单行线，车辆只能从东往西行开。而每逢春节、中秋节重大节日，唐人街会在指定日子（一般是某个星期六或星期日）禁止车辆通行，成为只向行人开放的步行街。 如今这条澳大利亚最古老的唐人街融合了众多的嬉皮酒吧和精品时尚店，散发出了崭新的风情，每到夜晚，在街灯、灯笼和霓虹灯的照耀下，唐人街显得格外绚丽璀璨，就像一座小小的不夜城。无论是沿着小巷漫步，还是登上街边坡梯来观景，都别有一番风情。
110407	6	1	2. 各色中餐美食 想要吃中式及亚洲美食，这里的食为先（Shark Fin）、宵夜店（Supper Inn）、龙舫皇宫（Dragon Boat）和西湖酒家（Westlake）等餐厅都值得推荐，而万寿宫（Flower Drum）则是著名的粤菜馆。唐人街也是墨尔本亚洲美食节的举办地点。
110407	9	1	3. 购物以及娱乐十分便利 唐人街上的各种商店的店员大多都会说普通话或粤语，在这里也可以买到羊皮、绵羊油等澳洲土特产，但记得还是要砍价。附近的Cohen Place还有一座华人历史博物馆（Chinese Museum），是了解澳洲华人移民历史的好地方。此外，唐人街也是墨尔本各种娱乐的集中地，经常上演歌剧的女王剧院（Her Majesty's Theatre）及数个电影院都在附近。
13562	1	1	墨尔本皇家植物园坐落在美丽的亚拉河南岸，距离市中心约2公里，来自澳大利亚甚至世界各地的上万种奇花异草在这里茁壮成长，无需门票，园内的建筑与体验活动也很丰富多彩。
13562	2	1	1. 儿童花园帮助孩子们探索自然世界 在儿童花园内，里面有许多互动的设施，孩子们可以尽情玩耍，与大自然零距离接触。儿童花园拥有帮助孩子们探索自然世界的一切事物：可以爬行的植物隧道，可以攀爬的岩石以及可以玩“捉迷藏”的竹林。 每年冬季，儿童花园都会因为维护而暂时关闭。其他季节的开放时间是周三-周日10:00-日落，在维多利亚学校假期期间每天都会开放。假期时间表参考：http://schoolholidaysaustralia.com/victorian-school-holidays/#VICB 儿童花园详情可以参考官网：http://www.rbg.vic.gov.au/visit-melbourne/attractions/children-garden
13562	6	1	http://schoolholidaysaustralia.com/victorian-school-holidays/#VICB
13562	8	1	http://www.rbg.vic.gov.au/visit-melbourne/attractions/children-garden
13562	9	1	2. 天文台探索灿烂星空 儿童花园的旁边就是天文台，亮黄色的外墙和银色的半圆顶非常容易辨认。建于1861-1863年，一直与维多利亚州的天文协会保持着紧密的联系。内部只对旅行团开放，一般的游客无法进入。参观天文馆一般都安排在晚上。
13562	12	1	3. 植物标本馆珍藏植物标本 儿童花园右边是植物标本馆，这是一栋白色的圆形建筑。馆内珍藏有120余万种植物标本，大部分来自澳大利亚的维多利亚州，一半以上的标本至少有上百年的历史了。馆内还有一个小型图书馆，收藏的是植物文学类书籍。不过遗憾的是，游客不允许入内。
13562	15	1	4. 热带温室 来到热带温室，在这里可以看到来自世界各地的热带植物，最佳的观赏时间是冬季。
13562	18	1	5. 植物园商店 植物园商店也就在旁边，专门提供以植物为主题的纪念品和礼品，共有两家店铺，一家是位于天文台附近的Observatory Shop，另一家是Lakeside Shop。可以先在官网查看：https://shop.rbg.vic.gov.au/然后去现场购买。
13562	21	1	https://shop.rbg.vic.gov.au/
110158	1	1	墨尔本大学始建于1853年，是维多利亚州最古老的大学，也是澳大利亚历史第二悠久的大学，只比悉尼大学晚三年。
110158	2	1	1. 古典建筑与现代建筑交相辉映 作为澳洲首屈一指的高等学府，墨尔本大学不仅有着浓厚的学术氛围，其哥特风格的建筑也值得人们细细品读。墨尔本大学的主校区位于墨尔本CBD区域北边的帕克维尔（Parkville），其古典的钟楼、老四方院等岩石建造与新式的多栋教学大楼交相辉映。 无论是在绿木成荫的明媚夏日，还是在黄叶飘零的寂静深秋，这里都有着令人陶醉的卓越风姿。你可以漫步在校园中，与充满活力的年轻学生擦肩而过，回想青葱岁月，或者坐在草坪上休憩，晒晒太阳，度过闲暇时光。
110158	6	1	2. 南草坪 帕克维尔校区是一个开放式的校园，没有气派的校门，却有十多个低调的出入口，可以自由进出。Grattan Street 街上的10号门（Gate 10）附近有著名的南草坪（South Lawn），很多学生会坐在这里的草坪上看书、聊天，气氛很不错。若赶上了毕业典礼，穿着学士袍的学生和他们的家人亲友都会聚在这里拍照。 草坪下是一个地下停车场，你可以找找看停车场的入口，是一个有着精美雕刻的石门，非常特别。 南草坪北面的老文科楼（Old Arts Building）是墨尔本大学最具标志性的建筑，高耸的古老钟楼非常显眼。老文科楼内有石造的长廊，尖尖的拱顶古典优雅，走一走，很适合拍照。 由走廊来到老四方院（Old Quad），可以看到红花树，是很多学生毕业照中一定会出现的。 南草坪的西面是百鲁图书馆（Baillieu Library），游客可以免费参观、随意翻阅图书，只是不能外借。在图书馆里还可以买到墨尔本大学的相关纪念品和书籍。
110158	13	1	3. 砖石小路 校园中有一条砖石小路Masson Road，是秋天落叶最多的地方。每到5月，这里的树叶开始泛黄，不同品种的树木有着红橙黄绿渐变的叶子，道路两旁的红色砖墙或深色石墙也显得格外应景，透着一股浪漫的气氛。 伊恩波特美术博物馆沿着Masson Road往东走到尽头左拐，会看到伊恩波特美术博物馆（Ian Potter Museum of Art），这里展出了许多学生优秀作品，同时也有固定的当代艺术展览，可以免费参观。博物馆建筑本身也颇有看点，其外墙上堆砌着不规则的知名雕塑，十分吸引眼球。
110158	17	1	4. 圣三一学院 坐落在校园西北角的圣三一学院（Trinity College）也不容错过，这是墨尔本大学十余个预科学院中年代最悠久的。圣三一学院由墨尔本的第一个大主教建立，因此这里有一座非常抢眼的红色教堂，与前方的绿地一起构成一道童话般的风景线。这里的环境十分静谧，爬满了常青藤的校长楼、种植着虞美人的花圃等景象都令人心旷神怡。
110158	20	1	5. 大学广场 从10号门过马路到Grattan Street 街的另一侧，就是大学广场（University Square），沿着中轴线的小径往南边走去，来到法学院新楼，站在楼上可以透过落地玻璃窗遥望墨尔本大学主校区的风景。
7290	1	1	大皇宫（又名大王宫），位于曼谷市中心，紧靠湄南河，是曼谷王朝的象征，是旅游者去泰国的钟爱之地。紧偎湄南河，由一组布局错落的建筑群组成，是暹逻式风格，汇集了泰国绘画、雕刻和装饰艺术的精华。
7290	2	1	皇宫建筑分布
7290	4	1	它有点像中国的故宫一样，是泰国曼谷王朝一世至八世的王宫，是历代王宫保存规模相当壮观、富有民族特色的王宫，现仍用于举行加冕典礼、宫廷庆祝等仪式活动。
7290	5	1	大皇宫建筑群有22座，主要建筑是4座具有特色的宫殿和1座玉佛寺。四座宫殿分别是武隆碧曼宫、阿玛林宫、节基宫和律实宫，从东向西一字排开。
7290	6	1	玉佛寺
7290	7	1	玉佛寺
7290	9	1	从帕兰路的大皇宫正门进入后就是玉佛寺，这里是游览大皇宫的开端，这里是泰国神圣的寺庙，寺庙的主体就是玉佛殿，里面供奉着一尊玉佛，你会看到泰国佛教徒对它的膜拜。
7290	10	1	武隆碧曼宫
7290	12	1	玉佛寺的后面就是武隆碧曼宫，一座法式风格的宫殿，由国王拉马五世为他的儿子建造。虽然后来的国王没有怎么使用这座宫殿，但现今仍有许多来访的贵宾都会住在这里。
7290	13	1	阿玛林宫
7290	15	1	武隆碧曼宫的旁边就是阿玛林宫，建于拉玛一世时代，当时是泰国最高法院所在地，之后成为君主接见臣民的场所。阿玛林宫由三个主要建筑物组成，即阿玛灵达谒见厅，宫廷的昭见仪式通常在这里举行；拍沙厅，君王的加冕礼在这里举行，里面有加冕坐的椅子；卡拉玛地彼曼殿，现在泰国国王生日庆典或授勋等重要仪式都在这里举行。
7290	16	1	节基宫
7290	18	1	阿玛林宫的旁边就是节基宫，这里是大皇宫的主要宫殿，国王举行就职大典的地方。节基宫的西面就是律实宫，这是大皇宫内先建造的皇殿，而且是一座泰国传统建筑。现今殿内放有历代国王、王后及个别皇族成员的骨灰，还安放着“珍珠之母”宝座，雕刻细致，在泰国首屈一指。现在，律实宫主要作为国王、王后、太后等王室人物举行丧礼的地方。
7290	19	1	游览完了建筑群后，如果有时间还可以去参观一下玉佛寺博物馆，了解一下各个宫殿的历史和修复情况。
7290	20	1	与卫兵合影
7290	22	1	来大王宫能看到有意思的场景就是很多游客都和身穿白色礼服的王家卫队的卫兵合影留念，对方非常友善。如果碰巧，说不定你还能看到王家仪仗队巡礼仪式。
7311	1	1	位于泰国曼谷的四面佛是泰国香火鼎盛的膜拜据点之一，深受明星的追捧。因为地处Central World等大型商场附近，因此这里也成为了曼谷知名的旅游观光胜地。在泰国及东南亚，四面佛被认为是仁慈无比的神祗，所以在拜佛之前要戒荤吃素。
7311	2	1	灵验之佛，香火旺盛
7311	4	1	四面佛位于伊拉旺神祠中，前后左右有四副面孔，分别代表慈、悲、喜、舍四种梵心，凡是祈求升天者必须勤修这四种功德。神像摆放在工艺精细的花岗岩神龛内，正襟危坐，全身金碧辉煌，四面都是同一面孔、同一姿态。由于它的灵验，为众人称道，因此这里的香火非常旺盛。
7311	5	1	参拜佛像，净化心灵
7311	7	1	进入四面佛的围栏，右手边有卖烧香用的贡品。第一次去参拜的人只要花20泰铢就能得到4个手腕粗的小花环、4根黄色蜡烛和12支香。 拜四面佛要顺时针方向逐面拜。双掌合十，把香夹在两手掌之间，或跪或拜都可以。从入口处佛面开始，留下蜡烛，然后许愿，三注香一个花圈顺时针拜四面，回第一面再拜一次。最后到左边净水处用锡碗盛出干净的水清洗水缸舀水，拍前额、脸、手臂，以求得四面佛的保佑，净化心灵。
7311	9	1	还愿仪式
7311	11	1	超过一次来参拜的人按还愿的方法有另外一套祭品。主要的区别是花环是那种一尺长的大花环，香的颜色也不同。这套还愿用的祭品价格在200泰铢左右，四面佛的还愿者还有一个重要的仪式就是在四面佛旁边的回廊下，请身穿泰国民族服装的舞者为你向四面佛跳一段祈祷和祝福的歌舞。门中念诵着还愿者的姓名，还愿者跪在舞者前面的蒲团上，可以选择2人、4人、6人，最多8人来跳这段祈祷的舞蹈。整个仪式约3分钟，离开四面佛前用清水清洗双手和面容，象征净化心灵。
7311	12	1	感受虔诚信众
7311	14	1	每日，都有很多来自世界各地的信众前往参拜或祈求。这尊佛像原是印度婆罗门教主神之一梵天，乃是创造世界的神，法力无边。泰国各地包括住家庭院内都有设置。四面佛在2006年曾经被毁过，现已重新修缮。令人印象深刻的是，天桥上路过的泰国人，看到远处的四面佛都会停下匆忙的脚步，向佛祖问好。此外，每当入夜以后，这里依然是灯火通明，香烟燎绕。
43782	1	1	湄南河又名昭披耶河，是泰国河流中水量最大、长度最长的河流，有泰国“河流之母”之称，同时也被誉为“东方威尼斯”。湄南河全长1352千米，纵穿泰国东南部，流经大城，贯穿曼谷市区，在城市交通运输及岸边居民生活中扮演着重要角色。
43782	2	1	便利的水上交通
43782	4	1	湄南河上的水上交通非常方便，昭披耶快船（Chao Phraya Express Boat）是曼谷市民日常生活的主要交通国内工具之一，也是游客经常搭乘的交通工具，白天游览湄南河时推荐乘坐此类快船，不仅价格便宜，同时还能带你前往曼谷的一些主要景点。
43782	5	1	白天湄南河有水上市场，运输船只往来；待天色渐暗，沿岸的灯光纷纷亮起，穿梭在河面上的观光游船纷纷出航，湄南河又展现出另一种风情。
43782	6	1	码头分布
43782	8	1	湄南河以中央码头（Saphan Taksin Station）为中点，往北以N表示，有N1-N33，共33个码头，数字越大就越北。往南有S1-S4等4个码头。线路主要有无色的本地线、橙线、黄线、绿线以及蓝线。一般游客乘坐较多的是橙线和蓝线，蓝线本身就是游船路线，主要针对游客，蓝线停靠的码头分别是N1（东方文华酒店）、N3（Si Phraya）、N5（唐人街）、N8（郑王庙，下船后需搭摆渡船到对岸、卧佛寺）、N9（大皇宫、玉佛寺）、N10（王船博物馆）和N13（考山路）。这条线路集中了湄南河上的主要景点，沿岸你可以看到宏伟壮丽、金光闪闪的寺庙、佛塔，一群群多姿多彩的佛教建筑，与市内高层建筑、居民住宅混建在一起，构成一道奇特、亮丽的风光。
43782	9	1	唐人街
43782	10	1	郑王庙
43782	11	1	卧佛寺
43782	12	1	大皇宫
43782	13	1	玉佛寺
43782	14	1	考山路
43782	15	1	游船线路导览
43782	17	1	不过，旅游蓝线只开到考山路，如果想去更远的地方，建议可以搭乘橙线，可以开到加都加周末市场甚至更远的地方。各个码头在曼谷地图上都会有标注，可以通过地铁、轻轨等交通工具加上步行前往。船票价格一般在13-32泰铢之间，一些大站都有售票亭，但还是建议在船上购票，千万别在码头上或相信别人购买Tourist Ticket，这样会非常贵。另外，一定要保管好你的船票以证明你已经买过票了。
43782	18	1	加都加周末市场
43782	19	1	各线路停靠站点、运营时间、票价可查看：
43782	20	1	http://www.chaophrayaexpressboat.com/en/services/。
43782	21	1	http://www.chaophrayaexpressboat.com/en/services/
43782	22	1	各类游船供游客选择
43782	24	1	当然，除了白天的景色外，作为游客来说，更多的人会选择夜游湄南河，虽然价格相对贵了一些，但是绝对物有所值。可以选择公主号（Chao Phraya Princess）或大珍珠号（Grand Pearl）这样的游览船，一般登船时间为晚上19:30左右，行程大约为2小时，费用为人均200元人民币左右。坐在豪华游船上，随着船身在河面摇荡，恍如皇室出巡一般。沿途会经过重要景点，所有景致在夜晚灯光的照射下，又有初次看见的新奇。船上还安排了烛光晚餐、有乐队和泰国经典舞蹈热情款待，另外还提供泰式和国际自助晚餐。
43782	25	1	具体游览信息详见：
43782	26	1	http://piao.ctrip.com/dest/t43782.html#ctm_ref=gs_ttd_290510_11_tkt_2_191_43782。
43782	27	1	http://piao.ctrip.com/dest/t43782.html#ctm_ref=gs_ttd_290510_11_tkt_2_191_43782
43782	28	1	如果有兴趣的话你还可以尝试坐一下长尾船，船夫会带你去任何你想去的地方，所需费用为每小时300-500泰铢，这也是游览湄南河不错的方式。租用这些船的最佳地点是萨通桥（Sathorn Bridge）的中央码头（Central Pier）。不过，长尾船的运营时间结束的较早，一般在18:00就停止运营了，游览时请注意时间上的安排。
43782	29	1	此外，如果不想坐船，傍晚时分，等太阳落山后，漫步在湄南河沿岸，看着晚霞落下，也是一种不错的选择。当然你也可以选一家湄南河边上的餐厅吃晚饭，一边品尝美食，一边欣赏河岸夜景。
43782	30	1	湄南河岸码头分布图：
43782	31	1	http://www.chaophrayaexpressboat.com/en/services/map-print.asp
43782	32	1	http://www.chaophrayaexpressboat.com/en/services/map-print.asp
7292	1	1	玉佛寺位于曼谷大皇宫的东北角，是曼谷的标志，是泰国旅游必到之地，历代王族都在这里举行重要的仪式。像泰国这样的佛教国家，宗教历来就是和王权不分家的，而玉佛寺也就是大皇宫的一部分，是泰国所有寺庙中最崇高的代表。
7292	2	1	大皇宫
7292	3	1	让人生畏的寺庙守卫 玉佛寺面积占整个大皇宫的四分之一，寺内建筑宏伟堂皇，金玉璀璨，融泰国诸佛寺特点于一身，是泰国国内最大的寺庙。
7292	6	1	玉佛寺面积占整个大皇宫的四分之一，寺内建筑宏伟堂皇，金玉璀璨，融泰国诸佛寺特点于一身，是泰国国内最大的寺庙。
7292	7	1	当你进入这座寺庙建筑群时，会看到一些有6米高、身穿战衣的让人生畏的雕像。这些雕像就是夜叉，他们是保护玉佛免受邪灵侵犯的守卫。你还可以看到一些描绘《拉玛坚》史诗的壁画。台阶上美丽的镀金半人半狮像（Apsonsi），其职责也是守卫寺庙。
7292	8	1	稀世珍宝玉佛像 供奉玉佛的玉佛殿共有40根四角型立柱，并在廊下装饰有112尊鸟形人身的金像。殿里很宁静，充满了香火的气味。
7296	8	1	乘摆渡船游览和到达
7292	11	1	供奉玉佛的玉佛殿共有40根四角型立柱，并在廊下装饰有112尊鸟形人身的金像。殿里很宁静，充满了香火的气味。
7292	12	1	玉佛由整块翡翠雕琢而成，由玻璃盖保护，上有多层华盖，基座相当高。此玉佛通体苍翠，经历过多次战火的劫难，是稀世之宝，直到1784年泰国国王才迎请玉佛至玉佛寺供奉，可谓命运多舛。佛像需要按照泰国一年三季的时间更换锦衣。而更换锦衣的仪式，则由国王亲自主持。
7292	13	1	虔诚的教徒 虽然佛像被安放在高高的祭坛上，但这并不能阻挡泰国的佛教徒对它的膜拜，他们相信玉佛能赋予他们精神价值，能帮助他们在下一世获得更美好的新生。在参观玉佛寺的时候，大多数泰国人都会向玉佛敬献贡品，然后还会向佛祖跪拜。拜过之后，你可以根据自己的意愿坐在佛祖面前祈祷或冥想。
7292	16	1	虽然佛像被安放在高高的祭坛上，但这并不能阻挡泰国的佛教徒对它的膜拜，他们相信玉佛能赋予他们精神价值，能帮助他们在下一世获得更美好的新生。在参观玉佛寺的时候，大多数泰国人都会向玉佛敬献贡品，然后还会向佛祖跪拜。拜过之后，你可以根据自己的意愿坐在佛祖面前祈祷或冥想。
7292	17	1	多个景点值得一看 除了玉佛殿之外，钟楼、藏经殿、先王殿、佛骨殿、叻达纳大金塔、尖顶佛堂、骨灰堂等也值得看看。寺院内更有矗立如林的佛塔，造型各异，色彩鲜艳，十分壮观。此外，大皇宫内还有一个玉佛寺博物馆，游览完玉佛寺后，来这个博物馆参观一下，了解一下更多的玉佛历史。
7292	20	1	除了玉佛殿之外，钟楼、藏经殿、先王殿、佛骨殿、叻达纳大金塔、尖顶佛堂、骨灰堂等也值得看看。寺院内更有矗立如林的佛塔，造型各异，色彩鲜艳，十分壮观。此外，大皇宫内还有一个玉佛寺博物馆，游览完玉佛寺后，来这个博物馆参观一下，了解一下更多的玉佛历史。
110031	1	1	提到曼谷，就没人不知道考山路。它就是这座城市的夜生活精灵，打车时只要你大声说出Kao San，司机一定就会给你一个“我知道”的微笑。考山路是背包客的大本营，也是游客喜爱的游玩地点。这里，街道纵横，各种档次的酒店和廉价旅馆遍布街区，临街的路边店铺，各色旅行社代理、外币兑换点，各种风味的饭店、酒吧、咖啡屋、按摩店铺以及本地特色的商品店鳞次栉比，应有尽有。要想了解曼谷的生活，来这里便可以一览无遗。
110031	2	1	事实上考山路只是一条长300米的小路，走一遍也不过就是15分钟左右，但是其每天夜晚的拥挤程度宛如人肉罐头。林立的广告牌有咖啡厅、酒吧、饭店、住宿的Logo，当然所有广告都与旅行有关。
110031	3	1	考山路离大皇宫、玉佛寺等景点，步行20-30分钟的时间。如果喜欢热闹的游客不妨在此住宿，但要注意酒吧会开到第二天早上，可能会影响休息。
110031	4	1	大皇宫
110031	5	1	玉佛寺
110031	6	1	白天的考山路是相对安静的，基本上要到中午11点以后一些店铺才会陆续开门。但是到了晚上这里就成了夜生活的天堂，酒吧、街头小吃、马杀鸡，热闹非凡。即便是深夜1、2点这里依旧是灯火通明，有些酒吧在凌晨5点左右还能看到老外在这里醒酒。
110031	7	1	考山路的街道两旁有很多酒吧，走在路上都能感觉到很大的有节奏的音乐声。这些酒吧几乎都有大的液晶电视或者投影电视，时不时的会播放一些足球比赛。各个酒吧的啤酒价格都差不多，大约一瓶在50-70泰铢左右。一些露天酒吧还提供点菜，沙拉、炒饭之类的都有，价格也不贵。
110031	8	1	除此之外，考山路还有7-11超市、Bigburger以及麦当劳等超市和快餐店。麦当劳门口有一个很大的麦当劳叔叔，两只手掌合并放在胸前，游客们会经常在这里与它合影。要想体验泰国传统小吃的也可以尝试一下路边摊，这里的水果Shake、芒果糯米饭、烧烤味道都很正宗，每样都是明码标价。
110031	9	1	除了酒吧之外，考山路的另一大特色就是马杀鸡（Massage）。马杀鸡可以说是泰国的“国粹”，考山路岂能让你失望。在考山路以及两旁昏暗的小巷子里，藏有数不清的马杀鸡场所，服务员大多是老实巴脚的农村泰妹。好在这里每家都明码标价，泰式按摩半小时120泰铢，1小时220泰铢。另外，这里还有一种小鱼按摩，就是把脚跑进鱼缸，会有无数条小鱼用嘴和你的脚接吻，据说这种小鱼不用喂食，而是靠吃人脚上脱落的死皮为生。走累的话不妨坐下来尝试一把。
110031	10	1	另外，如果是女孩子，还可以尝试一下街边的编发，价格不算很便宜，但挺有特色的。路边有很多卖纪念品的小店铺，从明信片、冰箱贴到唱片和比基尼样样都有，价格有便宜也有贵的，购买前一定要记得还价。
110031	11	1	与曼谷其它的景点不同，考山路的中国游客并不多，基本上很多都是欧洲人，这些老外到这里来就是为了呼吸自由的空气和荒废散漫的时光。在这里，外国人会显得更加的轻松惬意，他们穿着人字拖在大街上走来走去，或在咖啡馆里待上一天，晚上去酒吧凑个热闹。而且对于我们来说选个路边的露天座位，欣赏来来往往的各色行人也是一种不错的选择。
110031	12	1	考山路的青旅和民宿居多，一般100元人民币左右便可以租到不错的房子。对于那些穷游的人来说，几十块人民币的旅舍也有，地理位置优越，出门就能享受热闹的夜生活。此外，考山路上还有很多租车及私人旅游公司，你可以在这里租车或者选一个一日游的行程。一批批游客来到考山路，又有一批批游客离开考山路，考山路年复一年、日复一日重复演绎同样的故事。
7296	1	1	郑王庙，位于曼谷湄南河西岸的双子都市吞武里城，建于大城王朝，是泰国有名的王家寺庙之一。郑王庙是纪念泰国第41代君王的寺庙。据说当时郑王从大城到达吞武里的时候，正值黎明，因此郑王庙又名黎明寺。
7296	2	1	郑王庙，位于曼谷
7296	3	1	西岸的双子都市吞武里城，建于大城王朝，是泰国有名的王家寺庙之一。郑王庙是纪念泰国第
7296	4	1	41
7296	5	1	代君王的寺庙。据说当时郑王从大城到达吞武里的时候，正值黎明，因此郑王庙又名黎明寺。
7296	6	1	乘摆渡船游览和到达
7296	11	1	前往郑王庙游览比较普遍的交通方式就是在湄南河的8号码头乘坐摆渡，坐在摆渡船上你可以拍摄到郑王庙标志性的大乘舍利式塔，它素有“泰国埃菲尔铁塔”的美称。同时，你还能一边眺望老曼谷区景色，一边欣赏对岸吞武里区的风光。
7296	12	1	前往郑王庙游览比较普遍的交通方式就是在湄南河的
7296	13	1	8
7296	14	1	号码头乘坐摆渡，坐在摆渡船上你可以拍摄到郑王庙标志性的大乘舍利式塔，它素有
7296	15	1	“
7296	16	1	泰国埃菲尔铁塔
7296	17	1	”
7296	18	1	的美称。同时，你还能一边眺望老曼谷区景色，一边欣赏对岸吞武里区的风光。
7296	21	1	主殿庭院
7296	23	1	主殿庭院
7296	26	1	郑王庙的占地面积较大，仅次于大皇宫。一般游客来这里主要就是游览主殿和标志性的五座佛塔。寺院入口处有巨型守护神石像，首先进入的就是主殿所在的庭院，院门上的装饰都很漂亮，色彩斑斓，两侧伫立着两根高高的龙柱。院落中有一尊大象的铜像，院子的两旁还摆放着一些具有中国明朝时代人物特征的石雕像。据说都是从中国往泰国海运商品时用的压船石。主殿规模不大，正中间摆放着金色佛像，殿内的墙壁上绘满了壁画，有描写宫廷生活的，有描写战争场面的，细腻精美。
7296	27	1	郑王庙的占地面积较大，仅次于
7296	28	1	。一般游客来这里主要就是游览主殿和标志性的五座佛塔。寺院入口处有巨型守护神石像，首先进入的就是主殿所在的庭院，院门上的装饰都很漂亮，色彩斑斓，两侧伫立着两根高高的龙柱。院落中有一尊大象的铜像，院子的两旁还摆放着一些具有中国明朝时代人物特征的石雕像。据说都是从中国往泰国海运商品时用的压船石。主殿规模不大，正中间摆放着金色佛像，殿内的墙壁上绘满了壁画，有描写宫廷生活的，有描写战争场面的，细腻精美。
7296	29	1	参观五座佛塔主塔——巴壤塔
7296	31	1	参观五座佛塔主塔
7296	33	1	——
7296	35	1	巴壤塔
7296	38	1	出了主殿庭院后，朝靠近湄南河岸走就可以到五座佛塔所在的方形庭院。与普通泰式的小乘佛教尖顶佛塔不同，郑王庙内的一大四小佛塔的顶部都是粗顶。位于中心的主塔为79米高的婆罗门式尖塔——巴壤塔，底座和塔身均呈方表，层数很多，面积逐层递减，显得古朴而庄重。外面装饰以复杂的雕刻，并镶嵌了各种彩色的陶瓷片、玻璃和贝壳等。周围有四座与之呼应的陪塔，形成一组庞大而美丽的塔群。这些实心宝塔四面凹位都塑有一层一层的佛像。从地面到塔顶，都以各色碎瓷片镶成种种花饰。宝塔的地基部分绘有巨幅图画，佛像造型生动，雕工颇为精细。另外，塔身上还有很多装饰铃，在风中摆动发出清脆的响声。
7296	39	1	出了主殿庭院后，朝靠近湄南河岸走就可以到五座佛塔所在的方形庭院。与普通泰式的小乘佛教尖顶佛塔不同，郑王庙内的一大四小佛塔的顶部都是粗顶。位于中心的主塔为
7296	40	1	79
7296	41	1	米高的婆罗门式尖塔
7296	42	1	——
7296	43	1	巴壤塔，底座和塔身均呈方表，层数很多，面积逐层递减，显得古朴而庄重。外面装饰以复杂的雕刻，并镶嵌了各种彩色的陶瓷片、玻璃和贝壳等。周围有四座与之呼应的陪塔，形成一组庞大而美丽的塔群。这些实心宝塔四面凹位都塑有一层一层的佛像。从地面到塔顶，都以各色碎瓷片镶成种种花饰。宝塔的地基部分绘有巨幅图画，佛像造型生动，雕工颇为精细。另外，塔身上还有很多装饰铃，在风中摆动发出清脆的响声。
7296	46	1	主塔内有阶梯供游客攀爬，在塔上的观景平台上可以极目眺望湄南河对岸的大皇宫和曼谷市景。如果说这里的佛塔群在朝阳下显得熠熠生辉，那么当夕阳将整个区域映成琥珀色的黄昏时分，景色更加令人震惊。不管是在湄南河对岸，还是在佛塔脚下，摄影爱好者们都能捕捉到不同角度的美景。
7296	47	1	主塔内有阶梯供游客攀爬，在塔上的观景平台上可以极目眺望湄南河对岸的大皇宫和曼谷市景。如果说这里的佛塔群在朝阳下显得熠熠生辉，那么当夕阳将整个区域映成琥珀色的黄昏时分，景色更加令人震惊。不管是在湄南河对岸，还是在佛塔脚下，摄影爱好者们都能捕捉到不同角度的美景。
7296	50	1	其他游览
7296	52	1	其他游览
7296	55	1	当然，如果你不想攀爬主塔的话，也可以去寺内的佛堂、四方殿、王冠形尖顶的门楼和佛亭等游览一番。郑王庙中还有两座佛堂，在主塔的正面和湄南河的对面各有一座，其中一座是在建造郑王庙之时，堂内供奉着大大小小的佛像。另一座是拜殿，殿内有一座青铜佛塔，还有80尊佛像。现在供奉在玉佛寺内的玉佛，在吞武里王朝时就供奉在这里。
7296	56	1	当然，如果你不想攀爬主塔的话，也可以去寺内的佛堂、四方殿、王冠形尖顶的门楼和佛亭等游览一番。郑王庙中还有两座佛堂，在主塔的正面和湄南河的对面各有一座，其中一座是在建造郑王庙之时，堂内供奉着大大小小的佛像。另一座是拜殿，殿内有一座青铜佛塔，还有
7296	57	1	80
7296	58	1	尊佛像。现在供奉在
7296	59	1	内的玉佛，在吞武里王朝时就供奉在这里。
7296	60	1	寺门口有很多小摊，出售佛塔位还有昆虫标本。码头附近有一个像公园的地方，里面有假山，有兴趣可以游览一下。此外，每年举行的皇家托的卡定祭典，是郑王庙内较大的庆典，也是泰国王室的重要祭典之一。
110168	1	1	位于素贴山上的双龙寺（又名素贴寺）是清迈著名的佛教圣地，始建于公元1383年。传说古兰纳国王将一头背负佛骨舍利子的白象放归丛林，白象来到素帖山后鸣叫三声倒地西去，于是国王命人在此建造寺庙，寺庙门前的309级台阶由两条长龙雕塑守护，双龙寺因此得名。
110168	2	1	到达方式 进入寺庙可以从门口的300多级台阶走上来，如果不想爬也可以乘坐缆车上来（与台阶不在同一处，乘双条车前往时最好和司机确认位置），但就看不到标志性的双龙台阶了。
110168	5	1	进入寺庙可以从门口的300多级台阶走上来，如果不想爬也可以乘坐缆车上来（与台阶不在同一处，乘双条车前往时最好和司机确认位置），但就看不到标志性的双龙台阶了。
110168	6	1	参观须知 游览双龙寺建议不要穿着太露的服装，景点门口没有人验票，一切靠自觉。双龙寺内虽然人比较多，但大家说话都轻声细语。进入殿内需要脱鞋赤脚参观，没有固定存鞋的地方，因此一定要牢记自己放的地方。
110168	9	1	游览双龙寺建议不要穿着太露的服装，景点门口没有人验票，一切靠自觉。双龙寺内虽然人比较多，但大家说话都轻声细语。进入殿内需要脱鞋赤脚参观，没有固定存鞋的地方，因此一定要牢记自己放的地方。
110168	10	1	在庄严的主殿祈福 寺庙门口就是那座传说中的白象，你可以在这里合影留念。主殿位于整个寺庙的正中心，主殿的地板是瓷砖的，非常干净，不过建议尽量趁早游览，因为中午游览的话赤脚走在上面会很烫。
110168	13	1	寺庙门口就是那座传说中的白象，你可以在这里合影留念。主殿位于整个寺庙的正中心，主殿的地板是瓷砖的，非常干净，不过建议尽量趁早游览，因为中午游览的话赤脚走在上面会很烫。
110168	14	1	供奉释迦摩尼舍利子的金塔就在主殿的正中心，金灿灿的，按照当地人的习惯，可以绕着舍利子塔走上三圈，心中说一些为家人祈福的话。主殿内还有很多佛像和清迈本地的佛，几乎所有的佛像都是金碧辉煌的，唯独有一尊佛，通体碧绿，听说是缅甸国当初赠送的。另外，主殿内的走廊里还有很多佛像画，如果有兴趣可以绕一圈看看。
110168	15	1	殿里还有一些老僧人，当你进入之后就会给你撒圣水，说一些祈求来年平安的话。当然如果你很有心的话也可以捐点香火钱上香祈福，不管你捐的香火钱多少，都可以领到一串花和一炷香。
110168	16	1	风景绝佳的观景平台 出了主殿后，你可以去后方的观景点平台（View Point），在那里俯瞰清迈市区的全景。另外，寺庙里还有一些可爱的小和尚人物模型，可以拍照留念。在开满杜鹃花的庭院里漫步也是不错的选择。
110168	19	1	出了主殿后，你可以去后方的观景点平台（View Point），在那里俯瞰清迈市区的全景。另外，寺庙里还有一些可爱的小和尚人物模型，可以拍照留念。在开满杜鹃花的庭院里漫步也是不错的选择。
110168	20	1	购买食物和纪念品 泰国天气炎热，在寺庙的门口就有小卖部，可以买到饮料，如果饿了也可以买烤玉米充饥，价格不贵。另外，这里还有小礼品和首饰售卖，如果喜欢也可以买一些。
110168	23	1	泰国天气炎热，在寺庙的门口就有小卖部，可以买到饮料，如果饿了也可以买烤玉米充饥，价格不贵。另外，这里还有小礼品和首饰售卖，如果喜欢也可以买一些。
110168	24	1	双龙寺导览图
110443	1	1	塔佩门位于东边城墙，是清迈古城留存下来的完整城门。原先，清迈古城四周都是由褐红色砖墙围起的两米左右的城墙，后来，大部分的建筑都在岁月的更迭中消失了，留下的塔佩门也成为清迈的知名景点。
110443	2	1	正对塔佩门的路，就被称作塔佩路（Tha Pae Rd），乘火车抵清迈的游客多是经塔佩路从塔佩门进入古城的。
110443	3	1	清迈的地标建筑
110443	5	1	塔佩门是城市的一个重要地标，它开始被称为Pratu Chiang Ruak，因为在1296年国王曼格瑞统治期间，它位于Chiang Ruak村庄附近，后才改名Tha Phae Gate。去过清迈的游客必定去过东边城墙的塔佩门游玩。同时，现在这个让人印象深刻的大门还是一个很受欢迎的摄影点，红墙配蓝天，清晨或黄昏人较少时十分美丽，有沧桑感。来自世界各地的摄影师们会从不同的角度来捕捉城门美丽的瞬间。
110443	6	1	与执勤的军人合影
110443	8	1	从每天早上9点开始，塔佩门外已经非常热闹了，皮卡双条来回穿梭，塔佩门边上还有值勤的军人，每天很大一部分的工作就是和游人合影，几乎每时每刻都有游客排队轮流上前与他们合影，非常和谐有爱。不过要合影的话记得上前打个招呼哦，一般情况下都会同意。
110443	9	1	在广场上给鸽子喂食
110443	11	1	城门的两侧是护城河，门前是一个小型广场，没有夜市的时候，广场旁的河里有喷泉，还有很多很多饥饿的鸽子，有卖鸽食的小贩，10泰株很大一包，鸽子完全不怕人，把食物放在手上，它们就会朝你扑来，小孩特别喜欢。白天可以坐在城门旁树荫下的椅子上悠闲地坐着，喂喂鸽子，看看来往的行人。
110443	12	1	人声鼎沸的周日夜市
110443	14	1	当然吸引游客前来这里游玩的另一个主要因素就是塔佩门的夜市。周日夜市从塔佩门开始，沿主干道向西蔓延。夜市会售卖各类手工杂货，各种泰式美食，炒粉和肠粉的价格都在30泰铢左右，还有不少街头艺人和路边摊按摩。如果在夜市听到街上大喇叭起的时候，要注意入乡随俗停止说话。在这里可以买到各种小玩意做礼物，收市前会有所打折。
110443	15	1	周日夜市
110443	16	1	另外，城门旁边还有麦当劳、星巴克和一些小酒店，古老的城门搭配现代化的商店，宜古宜今，让人仿佛穿越时空。
110147	1	1	清迈大学是泰国北部首屈一指的高等学府，创立于1964年。校园中有草木繁茂的绿地、掩映在树林中宁静的水池，环境非常不错。大学主校区坐落在素贴山的东边，很多游客在前往素贴山时会顺便来参观一下。
110147	2	1	素贴山
110147	3	1	乘缆车进行游览
110147	5	1	现在清迈大学对游客观光采取了限制措施。如果你有在清迈大学就读的朋友或认识的当地人，或许可以带你进校园自由走动，对于大部分中国游客来说，需要在校园正门花60泰铢乘坐校方安排的观光车。
110147	6	1	清迈大学的校门小而精致，典型的泰式风情。进去后，游客就被安排乘坐观光车。大概每30分钟有一班车，会先带你在校园的中央区域转一圈，然后在佛楼、净心湖稍作停留，供游客下车走动、拍照，之后再返回正门结束游览，全程约30-40分钟。观光车上有中文讲解，但在乘车过程中游客不能随意下车。
110147	7	1	感受校园悠闲的学生岁月
110147	9	1	校园中的佛楼就像一座小型的寺庙，在外面可以看到大象石雕，里面还有佛像，但一般不能进去。净心湖有着十分漂亮的景色，湖中倒映着素贴山的轮廓，宁静美好。坐在观光车上看校园，还常会见到身着校服、骑着摩托车的男女学生，充满了清新的质感，令人不禁想起自己的青葱岁月。
110147	10	1	热闹的清迈大学夜市
110147	12	1	由于观光限制，你可能来不及领略更多的校园风光，但如果你时间充裕，倒不妨在晚上去学校正门的对面逛逛，那里有一个很大的夜市。在清迈大学夜市可以看到很多大学生，还能吃到许多当地小吃，便宜又美味，也比较干净，可谓是体验大学生夜生活的好地方。
110147	13	1	吃到撑的美食街
110147	15	1	在清迈大学后门，每到下午4点多钟之后，小贩们就会陆续出摊，沿街摆出各种让人眼花缭乱的美食摊子，直到10点多才会陆续收摊。清迈著名的小黄熊餐厅也位于这条美食街上。
110147	16	1	包括烤肉炸鸡、泰式米粉汤、鲜榨果汁、椰子牛奶冰等美食，绝对能让你挑花眼吃到撑。置身满是清迈大学学子的美食街内，仿佛自己都成了当地人。
110373	1	1	清迈古城建于1296年，呈四方形，每边城墙长约1.5公里，至今仍保留着部分老城墙和完整的护城河。作为清迈的老城区，它不仅是泰国重要的文化遗产之一，也可以说是清迈最令人着迷的地方。
110373	2	1	特色的古城区
110373	4	1	美丽清幽的清迈古城中遗迹众多，泰国传统的庙宇和宝塔是最大的特点，而且大多可以免费游览。这里也是充满生活气息的地方，聚集了各具特色的酒店、民宿、餐馆、咖啡厅等，周末还有热闹非凡的集市，可以感受到最真切的清迈人的生活。
110373	5	1	塔佩门
110373	7	1	古城的东南西北四个方向都有城门，其中东边的塔佩门（Tha Pae Gate）保存得最为完好，也是古城的一大地标，连接清迈新城的沿河地区和老城区。西门通往绿树成荫的清迈大学及素贴山。
110373	8	1	塔佩门
110373	9	1	清迈大学
110373	10	1	素贴山
110373	11	1	漫步或骑行小城
110373	13	1	游览清迈古城的最佳方式是漫步或租一辆自行车，前往各处的寺庙都很方便，还能钻进大街小巷中去感受绿荫葱翠的老城区及当地人的生活。如果是盛夏时前往，建议早、晚出门闲逛，中午就回旅馆睡觉、去按摩或者到咖啡馆发发呆。
110373	14	1	如果你着迷于寺庙的历史、文化和建筑，清迈古城是不容错过的旅行地。不妨沿着Ratchadamnoen路走一走，可以逛到许多寺庙，而清幽的寺院环境还会给你带来些许清凉。
110373	15	1	香火鼎盛的帕辛寺
110373	17	1	古城西部的帕辛寺（需捐赠20泰铢）会是你的首选，这是清迈香火最旺的寺庙，家喻户晓，供奉着最受人景仰的帕辛佛像（即狮佛），寺中还有数尊高僧的“真身”蜡像。
110373	18	1	帕辛寺
110373	19	1	神圣的大佛塔寺
110373	21	1	大佛塔寺是另一处神圣的寺庙，位于古城的中心位置。寺中最著名的是一座恢弘的四方形兰纳式佛塔，四面雕刻着精致的护塔灵蛇。寺庙主殿内挂满了福条，你可以花100泰铢求一个福条，并写上祝福的话。
110373	22	1	大佛塔寺
110373	23	1	清迈首座寺庙清曼寺
110373	25	1	坐落在古城东北边的清曼寺是清迈的第一座寺庙，由15头石象围绕着的佛塔很有特色，还能在殿堂内看到两尊珍贵的古老佛像。
110373	26	1	清曼寺
110373	27	1	众多参观、游览的休闲地
110373	29	1	还有盼道寺、帕烘寺等都值得去看看。另外，当你路过三王纪念碑时，也别忘了停下来合影留念，这座雕塑对清迈人有着很重要的意义。纪念碑后面是清迈市立艺术文化中心，感兴趣的话可以参观一下，还能吹吹空调。若是走累了，可以到附近的清迈女子监狱按摩馆花200泰铢体验传统的泰式按摩，不过最好在当天上午预约好，有时会排不上队。
110373	30	1	盼道寺
110373	31	1	帕烘寺
110373	32	1	三王纪念碑
110373	33	1	清迈市立艺术文化中心
110373	34	1	热闹非凡的周末夜市
110373	36	1	除了星罗棋布的庙宇，清迈古城的周末夜市也是吸引游客之处，因此建议你在周末或周末前夕抵达清迈，可以感受到令人为之疯狂的集市氛围以及绝无仅有的购物体验。
110373	37	1	塔佩门是周日夜市的起点，每到礼拜天傍晚开始实行交通管制，这里就变成步行者的天地，绵延将近1公里，热闹无比。富有民族风情的别致饰品、围巾、木雕等小商品琳琅满目，是挑选手信的好地方，还有各种便宜的泰式美食。由于夜市不仅针对游客，当地人也会来走走逛逛，所以价格水分并不高，砍价的余地较少。
110373	38	1	周日夜市
110373	39	1	悠闲的周六夜市
110373	41	1	周六夜市也值得一逛，位于南边清迈门（Chiang Mai Gate）外的Wualai路上，没有周日夜市那么喧嚣，晚上散步会很愉悦。当然，平日也有夜市，只是规模要小很多，气氛也很平淡。
110373	42	1	周六夜市
110373	43	1	住宿和用餐选择
110373	45	1	清迈古城可以游玩两三天，许多游客选择住在古城中，以此作为清迈之行的根据地。塔佩门附近集中了许多旅馆，750泰铢左右就可以住到环境还不错的Guest House。附近用餐的店也很多，可以找到连锁快餐店或各种当地小吃店，价格实惠，十分方便。
136940	1	1	素贴山位于清迈古城的西郊，海拔1600多米，是泰国著名的佛教圣地，而“素贴”就是指“仙友”。山上有双龙寺，在观景台可以俯瞰清迈全景；还建有蒲屏皇宫，是泰国国王的避暑行宫。山中森林茂密，百花争艳，气候凉爽宜人，空气十分清新，吸引着众多游客来此游玩。
136940	2	1	双龙寺
136940	3	1	蒲屏皇宫
136940	4	1	沿着盘山公路就可以上素贴山，但路陡弯路多，并不适合骑自行车。游客大多是从山下的清迈大学坐双条车上山。有些人会租一辆摩托车骑上山，但山路很陡、弯道很多，不建议这样做。
136940	5	1	清迈大学
136940	6	1	参观清迈最著名的双龙寺
136940	8	1	游览素贴山多是为了参观山腰的双龙寺（也叫素贴寺），门票30泰铢。寺庙建在高台上，要从寺前的300多级台阶走上去，台阶两旁的栏杆是两条几十米长的彩色多头神龙，造型奇特。寺中金碧辉煌的佛像、贴满金箔的舍利塔等都是很值得一看的景观。主殿后面就是可以俯瞰清迈古城全景的观景台。
136940	9	1	欣赏典型的泰式建筑蒲屏皇宫
136940	11	1	参观双龙寺后，往西有蒲屏皇宫，不过两地相距4公里以上的路程，你可以继续搭双条车过去，车费约20泰铢，但有时凑不齐客人就不会发车，包车的话会比较方便。
136940	12	1	蒲屏皇宫是典型的泰式建筑，白墙黄瓦、格调雅致。每年12月-1月，这里异常凉爽。1月-3月泰国王室成员会来此居住，其他月份游客可以参观，门票50泰铢，花园每天开放，而宫殿内部只在周末和节假日开放。园内草木葱郁，并种有玫瑰、鼠尾草等植物，景色美不胜收。
136940	13	1	周边游玩选择
136940	15	1	出了蒲屏皇宫继续往西北边去，那里还有一个村落，但较少有游客会再深入过去。在素贴山下，清迈大学旁边是清迈动物园，附近有宁曼路艺术街区，而在山的南边脚下还有清迈夜间动物园。你可以好好计划一下，在这片区域游玩一整天。
136940	16	1	清迈动物园
136940	17	1	宁曼路艺术街区
136940	18	1	清迈夜间动物园
8142	1	1	大佛塔寺（又名契迪龙寺或查里鲁安寺），是清迈古城内的寺庙，位于古城的中心位置，入口在帕抛拷路（Prapokkloa RD）上一条小巷内，巷口很窄，完全想象不到里面藏着一座如此恢宏的建筑。
8142	2	1	宁静安详的寺庙 刚进入寺庙大门，你会被参天大树吸引，庙内的树干上挂着许多写着箴言的木牌，和国内寺庙的那种烟气熏人，人头涌动的杂乱景象不同，这里有的只是宁静、安详与浓厚的学术氛围。
8142	5	1	神圣庄严的大佛塔 走进去之后，你就可以看到大佛塔，这座四方形兰纳式神圣佛塔建于1411年，高近80米。据说16世纪清迈发生一次大地震，佛塔的尖顶一夜之间塌毁。联合国教科文组织和日本政府曾出资重建佛塔，但尖顶却没法完成，因为没人确切知道原先佛的上部结构是什么模样，所以现在所见的是平顶的佛塔。 佛塔的四面雕有精致的护塔灵蛇，蛇身则随着阶梯而上，但这些也是后来修复重建的。塔身上有六座大象雕塑，原来的大象雕塑大多已毁坏，现在其中五座是重新雕刻的水泥制品，右方的一座缺了耳朵和象鼻的是保留下来的原作，有兴趣的可以仔细看一下。 佛塔一共有四面，只有一面有台阶，其它三面都修复成了斜坡，游客不能登塔。围绕着四方形佛塔走，在四方形佛塔的后面有两座殿堂。在每座殿堂中间的玻璃橱中端坐着身披迦裟的高僧蜡像，目光炯炯，栩栩如生。有一个小屋里面还有一尊大肚子穿着红色袈裟的坐佛，形态非常可亲。
8142	10	1	寺内建筑分布 总体来说寺庙的面积还算较大，有主殿、小佛殿、僧房。主殿内挂满了信徒及游客们的福条，花上100泰铢求一个福条，你可以在上面写上祝福的话。寺内还有图书馆、博物馆和僧侣学校，几乎每天你都可以看到穿着橘色长袍的僧人拿着厚厚的书本从僧舍内出来，坐在菩提树下静静地阅读。有时候一些外国游客还会坐下来和他们小声交谈，一边说一边做笔记，探讨一些关于人生哲学的话。
8142	13	1	在寺内闲庭漫步 不管是早晨还是傍晚，大佛塔寺都会给你不同的印象。如果是早晨去，光线比较好，庙舍前种植的兰花飘过阵阵幽香，肥硕的鸽子在石板路上悠闲地踱步，偶有僧人走过，你可以拍下这美好的瞬间。而傍晚在灯光衬托下的寺庙则格外雄伟壮观，流浪狗悠闲肆意的在庙里玩耍歇息，你可以徒步环绕整寺一圈，或坐在长椅上欣赏着美丽的黄昏。
8142	16	1	不管是早晨还是傍晚，大佛塔寺都会给你不同的印象。如果是早晨去，光线比较好，庙舍前种植的兰花飘过阵阵幽香，肥硕的鸽子在石板路上悠闲地踱步，偶有僧人走过，你可以拍下这美好的瞬间。而傍晚在灯光衬托下的寺庙则格外雄伟壮观，流浪狗悠闲肆意的在庙里玩耍歇息，你可以徒步环绕整寺一圈，或坐在长椅上欣赏着美丽的黄昏。
\.


--
-- Data for Name: raider_kind; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.raider_kind (raider_id, kind_id) FROM stdin;
13243	1
13318	1
13230	1
26696	1
1407447	1
46368	1
13444	1
22197	1
46387	1
49194	1
13200	1
46367	1
13131	1
13144	1
61258	1
110500	1
13125	1
110499	1
13592	1
13590	1
13645	1
13874	1
13591	1
13598	1
13607	2
15861	2
13604	2
15869	2
13616	2
13619	2
110165	2
45087	2
110407	2
13562	2
110158	2
7290	2
7311	2
43782	2
7292	2
110031	2
7296	2
110168	2
110443	2
110147	2
110373	2
136940	2
8142	2
190032784020200729838956	1
\.


--
-- Data for Name: raider_kind_instance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.raider_kind_instance (kind_id, kind_name) FROM stdin;
1	人文古迹
2	自然名胜
\.


--
-- Data for Name: travel_image; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.travel_image (travel_id, image_address) FROM stdin;
2917664	https://dimg03.c-ctrip.com/images/10010o000000fn05k7348_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/100s0g0000008nu8cE253_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/10090h0000008owy89068_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/10020m000000duyh602F6_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/fd/tg/g4/M06/85/D7/CggYHVZ7vraASC8ZABSsQMNaiwQ629_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/fd/tg/g4/M08/86/F2/CggYHFZ7vayAQc-yACVBPbK3mXw113_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/fd/tg/g3/M01/78/35/CggYG1Z7v9eAYpNgADFNQ4ULe8g908_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/fd/tg/g3/M04/7A/9C/CggYGVZ7v26AAYD4ADbIYfVKlFo337_C_750_420_Q90.jpg
2917664	https://dimg03.c-ctrip.com/images/100u0o000000fa1u6AA59_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/100212000000s670mADBC_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/fd/tg/g3/M04/B3/02/CggYG1bfy2eAdMgxADrLTo4ffiM860_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/fd/tg/g6/M06/A3/3D/CggYs1bfxzmAMb6_ADaV2A_dTsk917_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/fd/tg/g2/M01/8E/C8/CghzgFWxD9uAMJC-ACA8mflf6bg485_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/fd/tg/g2/M01/8E/C8/CghzgFWxD9iAO7Z5AA212Bvh1cM821_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/fd/tg/g1/M09/CD/F6/CghzflWxD9WAI6-dABz5LwWnSUw628_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/fd/tg/g1/M02/CD/F6/CghzflWxD86ACOpIACYwwpA171I454_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/10060n000000e1snbD98E_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/100j0s000000hts1mE725_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/10040s000000i85cyA0C7_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/10050v000000jnamu15CB_C_750_420_Q90.jpg
1646440	https://dimg03.c-ctrip.com/images/100k12000000shpq99E5F_C_750_420_Q90.jpg
1021291850	https://dimg03.c-ctrip.com/images/100h0k000000bdvct380B_C_750_420_Q90.jpg
1021291850	https://dimg03.c-ctrip.com/images/10050k000000be5z68A97_C_750_420_Q90.jpg
1021291850	https://dimg03.c-ctrip.com/images/10010h0000008sawrA71F_C_750_420_Q90.jpg
1021291850	https://dimg03.c-ctrip.com/images/100k0h0000008sap3A8FC_C_750_420_Q90.jpg
1021291850	https://dimg03.c-ctrip.com/images/100e0h00000091yvgA466_C_750_420_Q90.jpg
1021291850	https://dimg03.c-ctrip.com/images/fd/tg/g3/M00/9B/07/CggYGlbf0ByAQG7WAD8w5L74VpQ681_C_750_420_Q90.jpg
1021291850	https://dimg03.c-ctrip.com/images/100p0n000000dxjq4D211_C_750_420_Q90.jpg
2223702	https://dimg04.c-ctrip.com/images/300q0c0000006207tEF5A_C_750_420_Q90.jpg
2223702	https://dimg04.c-ctrip.com/images/300p0c000000620wt5B7A_C_750_420_Q90.jpg
2223702	https://dimg04.c-ctrip.com/images/300b0c0000006210p50A5_C_750_420_Q90.jpg
2223702	https://dimg04.c-ctrip.com/images/300o0c000000620zd4544_C_750_420_Q90.jpg
2223702	https://dimg04.c-ctrip.com/images/300g0c000000620f3F6BB_C_750_420_Q90.jpg
1022875352	https://dimg04.c-ctrip.com/images/300213000000v7ryr96C0_C_750_420_Q90.jpg
1022875352	https://dimg04.c-ctrip.com/images/300713000000vhdom02DE_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100n11000000re2s5E4ED_C_750_420_Q90.jpg
1022875352	https://dimg04.c-ctrip.com/images/300113000000vdmdb3136_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100f0n000000dyrbeDB79_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100h0r000000gqzkkA31B_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100k0s000000icygx2082_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100e10000000omv2hC5D4_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100e10000000p5lkb82B2_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100212000000s670mADBC_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100o11000000r60o5AFC9_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100k12000000shpq99E5F_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100u12000000sflqp9C17_C_750_420_Q90.jpg
1022875352	https://dimg03.c-ctrip.com/images/100613000000tf5u81B39_C_750_420_Q90.jpg
1022875352	https://dimg04.c-ctrip.com/images/300b13000000v33257C25_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100f0n000000dyrbeDB79_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100e10000000p5lkb82B2_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100n11000000re2s5E4ED_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100h0r000000gqzkkA31B_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100212000000s670mADBC_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100e10000000omv2hC5D4_C_750_420_Q90.jpg
1022900400	https://dimg04.c-ctrip.com/images/300f12000000s3tyiEB5C_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100k12000000shpq99E5F_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100u12000000sflqp9C17_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100613000000tf5u81B39_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100k0s000000icygx2082_C_750_420_Q90.jpg
1022900400	https://dimg03.c-ctrip.com/images/100o11000000r60o5AFC9_C_750_420_Q90.jpg
1022900400	https://dimg04.c-ctrip.com/images/300213000000v7ryr96C0_C_750_420_Q90.jpg
1022900400	https://dimg04.c-ctrip.com/images/300113000000vdmdb3136_C_750_420_Q90.jpg
1022900400	https://dimg04.c-ctrip.com/images/300i13000000uziv2BE26_C_750_420_Q90.jpg
1022900400	https://dimg04.c-ctrip.com/images/300v12000000seuykF1E0_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g4/M09/D2/AE/CggYHFbf0AWAMB_qAELVaovwbn4405_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g3/M0B/B3/34/CggYG1bfzxSAbLvyABpT0myMHMc967_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g4/M07/87/3F/CggYHFZ7v6yARTYWADwc2jTml8A547_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g2/M02/8B/77/Cghzf1Ww4ryAGQ2sAAeBr_fxNyQ416_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g2/M06/8A/33/CghzgVWw1AyAJhwYAF70fda5ISw855_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g2/M0A/89/44/CghzgVWwxi6ACZSEAAg4dbcQjaA737_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g2/M03/88/EE/CghzgVWwwaCAQU5KABKMohuOvcc414_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g2/M06/8A/84/Cghzf1Ww1AuAP_-aAFmCBwD4dPs329_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g1/M01/7C/D0/CghzfVWw1AKAeZdHAEs3EOx746U378_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g1/M06/CE/3E/CghzflWxE9iAWybOAAcIabf36ps489_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/8C/70/Cghzf1Ww8fGAExAsABmU-wrKBOo024_C_750_420_Q90.jpg
1740478	https://dimg03.c-ctrip.com/images/fd/tg/g2/M04/8C/B5/CghzgFWw8WiABkjAAAzIOBUP3jg179_C_750_420_Q90.jpg
1023219218	https://dimg03.c-ctrip.com/images/100s0g0000008nu8cE253_C_750_420_Q90.jpg
1023219218	https://dimg03.c-ctrip.com/images/10090h0000008owy89068_C_750_420_Q90.jpg
1023219218	https://dimg03.c-ctrip.com/images/100c0h0000008su2n7FAD_C_750_420_Q90.jpg
1023219218	https://dimg03.c-ctrip.com/images/10010h0000008sawrA71F_C_750_420_Q90.jpg
1023219218	https://dimg03.c-ctrip.com/images/100k0h0000008sap3A8FC_C_750_420_Q90.jpg
1023219218	https://dimg03.c-ctrip.com/images/100o0h0000009200j9775_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/fd/tg/g2/M01/32/F3/CghzgVVa8rmADnudACanrByAQzk013_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/fd/tg/g1/M07/CD/F6/CghzflWxD8qAMA5RACEJ2J3oRu0926_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/fd/tg/g1/M09/81/67/CghzfFWxD86AB5qRACf6EY-wzuM413_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/fd/tg/g2/M08/8E/27/CghzgVWxD-qAOFO3AB-KrM1I-4Y554_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/10020e00000076cizFAF2_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/10080c0000006nxrt8DEF_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/100a0k000000cbidoCAD2_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/100l0n000000e0abc12A8_C_750_420_Q90.jpg
1979124	https://dimg03.c-ctrip.com/images/100f0n000000e0d79056D_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/10050v000000jnamu15CB_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/10040s000000i85cyA0C7_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/100p0n000000dxjq4D211_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/100q0h000000924ac1118_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/100o0h0000009200j9775_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/10010h0000008sawrA71F_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/1002060000001gyx56BEB_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/100b050000000wodw3992_C_750_420_Q90.jpg
1021232487	https://dimg03.c-ctrip.com/images/fd/tg/g5/M00/A7/7A/CggYsFbf1BOAOR1hAD0Xn4rVDjk735_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g3/M06/B3/30/CggYG1bfzq6AVHcvADAwPooQ_ag612_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g5/M04/A6/A8/CggYr1bfzh2Ae4ZmAC5_1jrgyOI840_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g5/M07/A6/B7/CggYr1bfz1-AZGE4AEUjmi34s0I906_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g6/M01/A3/82/CggYslbfzAqACZXVAEZE8QA2NoI499_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/tg/351/896/087/5814f940f13a4a45a7efaee3089b8444_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g1/M04/7E/A5/CghzfVWw8VCABEEbABQc8A2gvZE092_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/tg/031/610/686/0701d52df90f45d1aa8368eadb105fe8_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g2/M01/8C/62/Cghzf1Ww8QqALoD-ABInDxiuqOk305_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/100c0h0000008su2n7FAD_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g2/M08/8B/1D/CghzgVWw4qqAEY7pABBNNh4CW-A678_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g1/M05/7C/D0/CghzfVWw1BOAA3w1AFVnGNblISI834_C_750_420_Q90.jpg
5515779	https://dimg03.c-ctrip.com/images/fd/tg/g2/M06/8A/33/CghzgVWw1AyAJhwYAF70fda5ISw855_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/10010o000000fn05k7348_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/100s0g0000008nu8cE253_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/100u0o000000fa1u6AA59_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/fd/tg/g3/M04/7A/9C/CggYGVZ7v26AAYD4ADbIYfVKlFo337_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/fd/tg/g3/M01/78/35/CggYG1Z7v9eAYpNgADFNQ4ULe8g908_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/fd/tg/g4/M08/86/F2/CggYHFZ7vayAQc-yACVBPbK3mXw113_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/fd/tg/g4/M06/85/D7/CggYHVZ7vraASC8ZABSsQMNaiwQ629_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/10020m000000duyh602F6_C_750_420_Q90.jpg
1020460554	https://dimg03.c-ctrip.com/images/10090h0000008owy89068_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/10090h0000008owy89068_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100l0h0000008s8wq1B9C_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100k0h0000008sap3A8FC_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100o0h0000009200j9775_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100p0h000000922km8B6D_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100m0i0000009rv29A283_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/10040i0000009rv9f3BE1_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100v0k000000cmxyhAE2A_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100u0k000000ccptxA02C_C_750_420_Q90.jpg
1018632811	https://dimg03.c-ctrip.com/images/100p0n000000dxjq4D211_C_750_420_Q90.jpg
1018205338	https://dimg03.c-ctrip.com/images/100s0g0000008nu8cE253_C_750_420_Q90.jpg
1018205338	https://dimg03.c-ctrip.com/images/10090h0000008owy89068_C_750_420_Q90.jpg
1018205338	https://dimg03.c-ctrip.com/images/100l0h0000008s8wq1B9C_C_750_420_Q90.jpg
1018205338	https://dimg03.c-ctrip.com/images/10010h0000008sawrA71F_C_750_420_Q90.jpg
1018205338	https://dimg03.c-ctrip.com/images/100o0h0000009200j9775_C_750_420_Q90.jpg
1018205338	https://dimg03.c-ctrip.com/images/100k0i0000009s7vt510F_C_750_420_Q90.jpg
1018205338	https://dimg03.c-ctrip.com/images/10040i0000009rv9f3BE1_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/10050v000000jnamu15CB_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/fd/tg/g5/M00/A7/7A/CggYsFbf1BOAOR1hAD0Xn4rVDjk735_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/100b050000000wodw3992_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/1002060000001gyx56BEB_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/10010h0000008sawrA71F_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/100o0h0000009200j9775_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/100q0h000000924ac1118_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/100p0n000000dxjq4D211_C_750_420_Q90.jpg
1017617144	https://dimg03.c-ctrip.com/images/10040s000000i85cyA0C7_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/100s0g0000008nu8cE253_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/10090h0000008owy89068_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/100l0h0000008s8wq1B9C_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/fd/tg/g3/M06/B3/45/CggYG1bf0EuAOtkMAE9PbQ79a2s869_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/100k0h0000008sap3A8FC_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/fd/tg/g4/M00/D2/A6/CggYHFbfz3GAJVsfACIxQZZMNdU350_C_750_420_Q90.jpg
2918034	https://dimg03.c-ctrip.com/images/fd/tg/g5/M08/A7/35/CggYsFbfzyKAFnkbAA1JAj4_7D8768_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g4/M0A/27/C3/CggYHlZpJQWAb33lADXQ_f75vaE894_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g4/M08/2C/60/CggYHFZpJUGAUXuvADoECEahFM4812_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/100k08000000360x59B0A_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/100d08000000360vw5A02_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g4/M09/17/32/CggYHlYkne2AUxVbACxY-YpKKzo856_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g3/M05/13/47/CggYGVYknjKAR2ZpACDezvyZ1k8318_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g5/M08/0D/70/CggYsFdCbvuASLJgACOqZJPDP8o805_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g6/M00/2A/85/CggYs1dCbkyAZxgOAC2gdHOFxVo903_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g6/M09/20/7C/CggYsldCbXKABwJ4ACpyLRy9klE946_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g5/M04/DB/C7/CggYr1b6NvmAbpuUABLA0Poto_c058_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g3/M00/FE/E5/CggYGlaPIMCANo3HAGCpwdsosIs478_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g4/M08/27/0A/CggYHVaPIvmAJx33ABiig9h12Is929_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g5/M07/A6/B7/CggYr1bfz1-AZGE4AEUjmi34s0I906_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g5/M0A/A7/3B/CggYsFbfz5CAJOd1AB4-eKt1wRs499_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g6/M01/A3/82/CggYslbfzAqACZXVAEZE8QA2NoI499_C_750_420_Q90.jpg
5516095	https://dimg03.c-ctrip.com/images/fd/tg/g4/M01/D2/78/CggYHFbfy8eANaghADq-jMXtcA4622_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100k12000000shpq99E5F_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100o11000000r60o5AFC9_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100212000000s670mADBC_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100e10000000p5lkb82B2_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/10050v000000jnamu15CB_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/10040s000000i85cyA0C7_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100t0s000000hubbf4567_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100j0s000000hts1mE725_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/10060n000000e1snbD98E_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100p0n000000dxjq4D211_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/10090m000000dq96h7C7F_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100j0m000000dnf6c6F47_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/10010m000000e0qhwCB6C_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/10080m000000do3w81063_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100g0m000000doj07D75C_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100s0m000000duspaF6E0_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/10020m000000duyh602F6_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100r0m000000dmc7x5012_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100f0m000000dnca2D695_C_750_420_Q90.jpg
1936768	https://dimg03.c-ctrip.com/images/100c0m000000dqjll0D0C_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g4/M09/20/6E/CggYHlaPIyuAPcYwADIwOgHBgH8608_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M06/81/68/CghzfFWxD--APYEmAAdU8RFh0-o702_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M00/80/BC/CghzfVWxD-uAHKlpAB0tamMo07A473_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M03/81/68/CghzfFWxD-iASIUZADFPuu2OTq8102_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g2/M05/8E/82/Cghzf1WxD96Ad6OpABH-zFRxCuw351_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g4/M08/20/51/CggYHlaPIbmAakKYACksQfqYnkc486_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M05/81/68/CghzfFWxD_SADdFLADPvWgEq2kQ268_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g3/M06/16/5C/CggYG1aPIJGAB-PDAIHf9X8RDCk213_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g4/M00/46/6F/CggYHFaAy-6AGmUlACns5xegb9o374_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g4/M00/45/34/CggYHVaAzMaAS5lgACJlU4yFxVI761_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g4/M04/3D/B4/CggYHlaAxKGAC_oUACHzs223tQ4294_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g2/M06/8A/84/Cghzf1Ww1AuAP_-aAFmCBwD4dPs329_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M01/7D/75/CghzfFWw1AiAF4RaAGfaepBJHOE723_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M08/7C/D0/CghzfVWw1AeAD1faACbdz3XoStU268_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M01/7C/D0/CghzfVWw1AKAeZdHAEs3EOx746U378_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g1/M06/CE/3E/CghzflWxE9iAWybOAAcIabf36ps489_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/8C/70/Cghzf1Ww8fGAExAsABmU-wrKBOo024_C_750_420_Q90.jpg
5516072	https://dimg03.c-ctrip.com/images/fd/tg/g2/M04/8C/B5/CghzgFWw8WiABkjAAAzIOBUP3jg179_C_750_420_Q90.jpg
1655500	https://dimg03.c-ctrip.com/images/fd/tg/g4/M09/CC/47/CggYHlbfz0qAPeFsACsy7XSMNZQ171_C_750_420_Q90.jpg
1655500	https://dimg03.c-ctrip.com/images/fd/tg/g5/M00/A6/BA/CggYsVbfz5-AF_T2ADjRGVzo8es476_C_750_420_Q90.jpg
1655500	https://dimg03.c-ctrip.com/images/fd/tg/g6/M01/A3/6B/CggYs1bfyvGAZUjrAC2a_T6R4SE022_C_750_420_Q90.jpg
1655500	https://dimg03.c-ctrip.com/images/fd/tg/g5/M02/A6/7B/CggYr1bfypuAJ8hXADkx0Wbskqc811_C_750_420_Q90.jpg
1655500	https://dimg03.c-ctrip.com/images/fd/tg/g5/M03/A6/AD/CggYsVbfznWAKFktACbnNd4QnyM786_C_750_420_Q90.jpg
1655500	https://dimg03.c-ctrip.com/images/fd/tg/g5/M0A/A6/86/CggYsVbfy1CAUS83ADxSNZdp35Q583_C_750_420_Q90.jpg
1023217846	https://dimg03.c-ctrip.com/images/100212000000s670mADBC_C_750_420_Q90.jpg
1023217846	https://dimg03.c-ctrip.com/images/10050v000000jnamu15CB_C_750_420_Q90.jpg
1023217846	https://dimg03.c-ctrip.com/images/100o11000000r60o5AFC9_C_750_420_Q90.jpg
1023217846	https://dimg03.c-ctrip.com/images/100k12000000shpq99E5F_C_750_420_Q90.jpg
1024680990	https://dimg03.c-ctrip.com/images/100d0s000000i7ls5B65D_C_750_420_Q90.jpg
1024680990	https://dimg03.c-ctrip.com/images/1003060000001ee7f2ACA_C_750_420_Q90.jpg
1024680990	https://dimg03.c-ctrip.com/images/100i0s000000hoew3B8C9_C_750_420_Q90.jpg
1024680990	https://dimg03.c-ctrip.com/images/100q0x000000l763oF88A_C_750_420_Q90.jpg
1024680990	https://dimg03.c-ctrip.com/images/100o10000000otfoyCF75_C_750_420_Q90.jpg
1024680990	https://dimg03.c-ctrip.com/images/10030y000000m1byo8767_C_750_420_Q90.jpg
1024680990	https://dimg03.c-ctrip.com/images/100g0y000000med1bEC42_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/fd/tg/g4/M00/51/D1/CggYHFZuMgOAb2AcACnzeVF12JU671_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100d0s000000i7ls5B65D_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/1003060000001ee7f2ACA_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100i0s000000hoew3B8C9_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100q0x000000l763oF88A_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100o10000000otfoyCF75_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/10030y000000m1byo8767_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100g0y000000med1bEC42_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100o0h000000906nl1C2E_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100u0i0000009ceil2D6F_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/100a0k000000ccks3C0E9_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/10020k000000ckvgi8061_C_750_420_Q90.jpg
1024685033	https://dimg03.c-ctrip.com/images/fd/tg/g6/M01/A3/68/CggYs1bfyrKARK85ADyHt7zyG1g769_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300w10000000pl3scB8AE_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300512000000s6bni1DED_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300a12000000s54si2DA0_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300312000000s5jn278CA_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300i180000014dh4lAA2A_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/3005180000013yy9tA722_C_750_420_Q90.jpg
71801	https://dimg03.c-ctrip.com/images/100m10000000p4ws5273C_C_750_420_Q90.jpg
71801	https://dimg03.c-ctrip.com/images/100110000000p8g7kFFA1_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/3007180000014d4nv3856_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300t13000000uwcxj33C4_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300813000000uwjtm819D_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300k13000000v0hpl5AC8_C_750_420_Q90.jpg
71801	https://dimg03.c-ctrip.com/images/100j10000000ov1gjC5E2_C_750_420_Q90.jpg
71801	https://dimg03.c-ctrip.com/images/100g0x000000lgiqq267E_C_750_420_Q90.jpg
71801	https://dimg03.c-ctrip.com/images/100h0y000000m2z1l62C2_C_750_420_Q90.jpg
71801	https://dimg03.c-ctrip.com/images/100l10000000o3vtk6BB2_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300413000000uvajz5DF2_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300710000000pvr0o9390_C_750_420_Q90.jpg
71801	https://dimg04.c-ctrip.com/images/300510000000phkn49045_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300b10000000phgec0931_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300m10000000pog9c6B43_C_750_420_Q90.jpg
36838	https://dimg03.c-ctrip.com/images/100m10000000p4wswFEBA_C_750_420_Q90.jpg
36838	https://dimg03.c-ctrip.com/images/100j10000000ov1gjC5E2_C_750_420_Q90.jpg
36838	https://dimg03.c-ctrip.com/images/100g0x000000lgiqq267E_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300l14000000w74v7CA09_C_750_420_Q90.jpg
36838	https://dimg03.c-ctrip.com/images/100512000000s1qv7F244_C_750_420_Q90.jpg
36838	https://dimg03.c-ctrip.com/images/100e11000000r8d0nB907_C_750_420_Q90.jpg
36838	https://dimg03.c-ctrip.com/images/100i11000000r5zqpB6ED_C_750_420_Q90.jpg
36838	https://dimg03.c-ctrip.com/images/100u12000000sflqp9C17_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300i13000000u7aef88A6_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300i14000000w5sdz1FAA_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300614000000w7l9v0723_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300a14000000w8avpBB39_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300k14000000wb5ud168B_C_750_420_Q90.jpg
36838	https://dimg04.c-ctrip.com/images/300t14000000w711p628D_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300c10000000phplw5765_C_750_420_Q90.png
1009991988	https://dimg04.c-ctrip.com/images/300s10000000ply60857F_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300w10000000pl3scB8AE_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300f10000000pf3adB865_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300110000000przuj7829_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300p0x000000l99zz551D_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300m10000000pog9e8A89_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300g0e00000070irx7AA4_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300m0x000000lm3kz3E2F_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/30060x000000le27u7775_C_750_420_Q90.jpg
1009991988	https://dimg03.c-ctrip.com/images/100e11000000r8d0nB907_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300l12000000s3zdj1D18_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300r0x000000l8kebFCED_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300r0x000000l8kecED0C_C_750_420_Q90.jpg
1009991988	https://dimg04.c-ctrip.com/images/300a0x000000lbgt3657F_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300j1b000001abiv26641_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/30081b000001ac7b01952_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300r1b000001aafid1A5C_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300q16000000zfmmt0AD8_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300r13000000uyja3C013_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/30070e00000075um6F4A4_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/30040s000000hlk5c6FE8_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300r0e00000075thj4FA2_C_750_420_Q90.jpg
2556409	https://dimg03.c-ctrip.com/images/1009050000000s4sd7C94_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300r0e00000070j3qB0A4_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/30050e00000070j7c4C91_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300k0s000000hqt6t7D98_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300h0s000000ho5dnF0FF_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/30070s000000i3bc16A7E_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300s13000000vawhc7701_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300b13000000v6euc97CF_C_750_420_Q90.jpg
2556409	https://dimg04.c-ctrip.com/images/300w16000000zkdh6E842_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300d14000000wm3e99637_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300314000000wpawv41DB_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300h14000000wp5aa1EC0_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300214000000wunkdBBBC_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300s13000000tqmht130B_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300q13000000tl1a6FAEE_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300c13000000tme2qAABE_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/30030u000000j43oz71B7_C_750_420_Q90.jpg
1019194061	https://dimg03.c-ctrip.com/images/100w0h0000008x1147950_C_750_420_Q90.jpg
1019194061	https://dimg03.c-ctrip.com/images/100g0d0000006ri0u7DC6_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300g0u000000j32bw19BE_C_750_420_Q90.jpg
1019194061	https://dimg03.c-ctrip.com/images/100n0g000000860a87F3F_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300g14000000wo9l7F518_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300814000000wnrps1D65_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300814000000wnrpu7E23_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300u14000000wnjp920BB_C_750_420_Q90.jpg
1019194061	https://dimg04.c-ctrip.com/images/300914000000wpz832EB7_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300512000000s6bni1DED_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300910000000pivgs14DE_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300v10000000prinz7141_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300312000000s5jn278CA_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300310000000pi75wCF27_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300t13000000v3j1b1BF9_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300b13000000v5v9pA9DA_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300u18000001411bc33C9_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/30091800000143gty97A2_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/300e1800000143tbv7636_C_750_420_Q90.jpg
1018919513	https://dimg03.c-ctrip.com/images/100u0j000000aylrw28C3_C_750_420_Q90.jpg
1018919513	https://dimg04.c-ctrip.com/images/30010b0000005j6nj4F2F_C_750_420_Q90.jpg
1018919513	https://dimg03.c-ctrip.com/images/100f0e00000070xs08643_C_750_420_Q90.jpg
1018919513	https://dimg03.c-ctrip.com/images/100g0p000000fwxxyF33B_C_750_420_Q90.jpg
1018919513	https://dimg03.c-ctrip.com/images/100l0p000000fyngf4411_C_750_420_Q90.jpg
1018919513	https://dimg03.c-ctrip.com/images/100e0e00000070zh8D93B_C_750_420_Q90.jpg
1018919513	https://dimg03.c-ctrip.com/images/10070p000000gbnxh5F43_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/100b0z000000mldc22EB1_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/100912000000rp2qk2446_C_750_420_Q90.jpg
2632836	https://dimg04.c-ctrip.com/images/30030x000000lhyxy2C05_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/100j0u000000jgnu4F0C2_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/100h0z000000mkrvx0A4A_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/10010t000000intc3E7B1_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/10080y000000m1mf7C069_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/100b0r000000gs1rgA123_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/10060y000000melhi5193_C_750_420_Q90.jpg
2632836	https://dimg03.c-ctrip.com/images/100l0y000000me5dm8596_C_750_420_Q90.jpg
2632836	https://dimg04.c-ctrip.com/images/300m0x000000lpmjhF8A5_C_750_420_Q90.jpg
2632836	https://dimg04.c-ctrip.com/images/300d13000000uyw2y1F44_C_750_420_Q90.jpg
2632836	https://dimg04.c-ctrip.com/images/300k13000000v4jwc91AC_C_750_420_Q90.jpg
2632836	https://dimg04.c-ctrip.com/images/300713000000vh21pC28B_C_750_420_Q90.jpg
1017168449	https://dimg04.c-ctrip.com/images/300e13000000v4gvb48AB_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/10080g00000085z9hFCD7_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/fd/tg/g6/M09/68/64/CggYtFcV2SSADLuCAB5GztxYGsw573_C_750_420_Q90.jpg
1017168449	https://dimg04.c-ctrip.com/images/30020e00000075tj59ACA_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/fd/tg/g1/M08/86/8F/CghzfVWmMbaABz2OACLUfXLrytA415_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/100l050000000s4qxFCF9_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/100d050000000s4rgD160_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/10010o000000f07qn2F2A_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/fd/tg/g5/M09/69/DA/CggYr1cV2QqAFT3qAB3BotfTfEY724_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/100e080000003ijup0098_C_750_420_Q90.jpg
1017168449	https://dimg03.c-ctrip.com/images/fd/tg/g1/M08/7C/61/CghzfFWww2uAVwo2AEO5gtV7nOs315_C_750_420_Q90.jpg
1021931014	https://dimg03.c-ctrip.com/images/fd/tg/g1/M08/7C/61/CghzfFWww2uAVwo2AEO5gtV7nOs315_C_750_420_Q90.jpg
1021931014	https://dimg03.c-ctrip.com/images/1006060000001egmu73DE_C_750_420_Q90.jpg
1021931014	https://dimg03.c-ctrip.com/images/100d050000000s4rgD160_C_750_420_Q90.jpg
1021931014	https://dimg03.c-ctrip.com/images/100l050000000s4qxFCF9_C_750_420_Q90.jpg
1021931014	https://dimg03.c-ctrip.com/images/1005050000000s4pq3414_C_750_420_Q90.jpg
1021931014	https://dimg03.c-ctrip.com/images/fd/tg/g1/M08/86/8F/CghzfVWmMbaABz2OACLUfXLrytA415_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300910000000pivgs14DE_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300n10000000pfj3wBB8E_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300o10000000pfb8g0B17_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300310000000pi75wCF27_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300312000000s5jn278CA_C_750_420_Q90.jpg
1011208034	https://dimg03.c-ctrip.com/images/100u0j000000aylrw28C3_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300d0y000000lm5b75E82_C_750_420_Q90.jpg
1011208034	https://dimg03.c-ctrip.com/images/fd/tg/g2/M09/88/53/Cghzf1Wwtk6AbCYZACTQN_b3IN4647_C_750_420_Q90.jpg
1011208034	https://dimg03.c-ctrip.com/images/fd/tg/g6/M08/E9/27/CggYs1b6SEOADcuMABXm91vIke0018_C_750_420_Q90.jpg
1011208034	https://dimg03.c-ctrip.com/images/fd/tg/g5/M08/6B/BA/CggYsFcV18aACjyiABjE_uBHFyE920_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/30030i000000997yg79AC_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300g0i000000998o6B011_C_750_420_Q90.jpg
1011208034	https://dimg04.c-ctrip.com/images/300e0i000000997xl99C8_C_750_420_Q90.jpg
1011208034	https://dimg03.c-ctrip.com/images/fd/tg/g6/M04/67/B8/CggYtFcV19OAXddWABbMXocOLYg166_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300g0b000000579bsF41E_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300r0b00000057930F0D3_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300t0b00000057a5g24CE_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300g0e00000070irx7AA4_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/30050e00000070j7c4C91_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300q0e00000070igq49C3_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300o0e00000070jpo2B34_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300c0e00000070j5o4D21_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300r0e00000070j3qB0A4_C_750_420_Q90.jpg
1024942188	https://dimg04.c-ctrip.com/images/300p0e00000070k6sA6F1_C_750_420_Q90.jpg
1024942188	https://dimg03.c-ctrip.com/images/fd/tg/g6/M01/91/2C/CggYslcdkZSAfjP7ABIysq26Gx4599_C_750_420_Q90.jpg
1024942188	https://dimg03.c-ctrip.com/images/fd/tg/g2/M04/29/DD/Cghzf1WTqhSAfxusAA6wcmtaB7c306_C_750_420_Q90.jpg
1024942188	https://dimg03.c-ctrip.com/images/fd/tg/g2/M09/89/86/CghzgVWwygSAE2agAAtoZ5fnuIE323_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100i11000000r5zqpB6ED_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/10060d0000006scecADC2_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100810000000q2qx2A1EA_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100s0s000000hqax9E2E4_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100d0z000000n9t5hCD04_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/10040z000000nczbj49BE_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100h0m000000dgw1e3CB0_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100a0e00000076pui5287_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/10010y000000mecveAF69_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/10050y000000m15ae8977_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100l0z000000ncx6yD3EB_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100a0y000000m5q1f59DC_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100b0z000000mldc22EB1_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100b0r000000gs1rgA123_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100g0y000000ment86B37_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/10060y000000melhi5193_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100r0y000000mcefmE017_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100r12000000se71r433B_C_750_420_Q90.jpg
1014187071	https://dimg03.c-ctrip.com/images/100o0d0000006sdd4F6EA_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100a0y000000m5q1f59DC_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/10070s000000hypymAAE6_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/10050y000000m10iw48D7_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100h0z000000mkrvx0A4A_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100l0z000000ncx6yD3EB_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100b0z000000mldc22EB1_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/10040z000000nblbj31CD_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/10080z000000ncyzwE499_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/10040y000000mcyoc61A7_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100r0y000000mcefmE017_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/10060y000000melhi5193_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100l0y000000me5dm8596_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100u0y000000mdyoxEC7F_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100i0y000000mcu9yBBC7_C_750_420_Q90.jpg
1021086987	https://dimg03.c-ctrip.com/images/100v0p000000gamlgE533_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/100n0m000000diudc9789_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/100i0g00000085zqvABA6_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/fd/tg/g2/M06/8E/AE/CghzgVWxGEOAb0GzACx2GAIKRRE387_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/1003070000002ha3eD9C3_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/100t070000002ha2iDFE1_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/fd/tg/g4/M08/10/3D/CggYHlaONkKAETCEACX7bKSpJJE650_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/fd/tg/g3/M01/06/7D/CggYG1aONeKAPC1IAB6njDjLgiA931_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/fd/tg/g3/M08/EF/2C/CggYGlaOOMiACeckACJJXj7Tyy0238_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/fd/tg/g6/M05/3E/7C/CggYslbOZ7KADTTzAA3sjkNfoGE218_C_750_420_Q90.jpg
1014539361	https://dimg03.c-ctrip.com/images/fd/tg/g3/M01/9F/55/CggYGlXRrKyAP9CsAB3GKh2N1Lk012_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/100b060000001vnqp6B0F_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/10050q000000gc1haAFC6_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g2/M09/A4/18/CghzgFVkNq6ADrmOABuwB4hoSfQ495_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/1003060000001vnof1F51_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g2/M03/93/BF/CghzgVWmPwWAHCKEACMVpZatqlc925_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g3/M0A/FF/22/CggYGlXddAWATHX1ABwdDVL9GIU149_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/10050500000013nf71073_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g2/M0B/8B/B8/CghzgFWw4hSARAJzACMri9ng4Og734_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/10070c00000065931A236_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g3/M06/5D/1D/CggYG1YzLpKARxUtAFND3nsoq7k492_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g4/M02/37/84/CggYHVbT_YeAa6a5AB_J9QQuj_A897_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g4/M09/37/8D/CggYHVbT_gyASrOqACLrSuc_LUg996_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g6/M0A/08/3E/CggYslbT_Z6AWv8pACb5Kz6q_PU259_C_750_420_Q90.jpg
3422942	https://dimg03.c-ctrip.com/images/fd/tg/g1/M04/C7/78/CghzflWwsf-ALKkIADEDCkUGIGI783_C_750_420_Q90.jpg
2520032	https://dimg03.c-ctrip.com/images/100i090000003xpuwC142_C_750_420_Q90.jpg
2520032	https://dimg03.c-ctrip.com/images/10080e000000784ka8305_C_750_420_Q90.jpg
2520032	https://dimg03.c-ctrip.com/images/100t0f000000793c82632_C_750_420_Q90.jpg
2520032	https://dimg03.c-ctrip.com/images/100j0f0000007975h9829_C_750_420_Q90.jpg
2520032	https://dimg03.c-ctrip.com/images/10070f000000793s9FAD7_C_750_420_Q90.jpg
2520032	https://dimg03.c-ctrip.com/images/100g0d0000006tl366454_C_750_420_Q90.jpg
2520032	https://dimg03.c-ctrip.com/images/10090f000000795pw0DE0_C_750_420_Q90.jpg
1018965634	https://dimg04.c-ctrip.com/images/300c0o000000esn23A680_C_750_420_Q90.jpg
1018965634	https://dimg04.c-ctrip.com/images/300a0o000000er9f5A594_C_750_420_Q90.jpg
1018965634	https://dimg04.c-ctrip.com/images/300h0o000000erbs3D771_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/100l0f0000007jq23ADAB_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/100b0g00000087r423881_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/100g0h0000008oohc4BB5_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/100h0h0000008p9zjD429_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/100u0k000000bhz28771D_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/100j0k000000bizzj908F_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1018965634	https://dimg03.c-ctrip.com/images/100k0m000000e206361AF_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100g0h0000008oohc4BB5_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100w0h0000008oozy089C_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/10090q000000gohvrA50C_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100b0g00000087r423881_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100d0s000000hk13a0EEC_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/10030g00000087q2h6149_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100h0h0000008p9zjD429_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100a0g00000087pk666A7_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100v0t000000im8lb3B1D_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100d0e00000071touFBA9_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/1006090000003xpht4E13_C_750_420_Q90.jpg
1024280216	https://dimg03.c-ctrip.com/images/100u0k000000bhz28771D_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/100b0f000000794x2192F_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/100d0e00000071togE9D6_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/100e0e00000071vbqF9B4_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/100u0y000000m7amc2F2B_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/100d0s000000hk13a0EEC_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/100g0h0000008oohc4BB5_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/10050y000000luriiDD40_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/100q0h0000008oo6rDC3E_C_750_420_Q90.jpg
1021931445	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100e0e00000071vbqF9B4_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100q0h0000008oo6rDC3E_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/10050y000000luriiDD40_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100g0h0000008oohc4BB5_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100d0s000000hk13a0EEC_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100u0y000000m7amc2F2B_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100e0g0000008nvsiE7AB_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100o0h0000008tu2yE77E_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100j0h0000008patp7AB3_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100h0h0000008p9zkC408_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100d0e00000071togE9D6_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100b0f000000794x2192F_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100u0h0000008x0ltE878_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100b0q000000gohf211E9_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100e0s000000ibtgs7880_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100w0h0000008op004CE4_C_750_420_Q90.jpg
1024139739	https://dimg03.c-ctrip.com/images/100w0m000000dkj6o6665_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/100w0h0000008oozy089C_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/100b0g00000087r423881_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/100l0f0000007jq23ADAB_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/100k0h0000008rq9eDB54_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/100j0h0000008patp7AB3_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/100a0g00000086sko031F_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/10040f0000007gonxCEEF_C_750_420_Q90.jpg
1019686314	https://dimg03.c-ctrip.com/images/100u0h0000008x0ltE878_C_750_420_Q90.jpg
1024279184	https://dimg03.c-ctrip.com/images/100i090000003xpuwC142_C_750_420_Q90.jpg
1024279184	https://dimg03.c-ctrip.com/images/100j0f0000007975h9829_C_750_420_Q90.jpg
1024279184	https://dimg03.c-ctrip.com/images/100t0f000000793c82632_C_750_420_Q90.jpg
1024279184	https://dimg03.c-ctrip.com/images/10090f000000795pw0DE0_C_750_420_Q90.jpg
1024279184	https://dimg03.c-ctrip.com/images/10080e000000784ka8305_C_750_420_Q90.jpg
1024279184	https://dimg03.c-ctrip.com/images/100g0d0000006tl366454_C_750_420_Q90.jpg
1024279184	https://dimg03.c-ctrip.com/images/10070f000000793s9FAD7_C_750_420_Q90.jpg
1023616233	https://dimg03.c-ctrip.com/images/100i090000003xpuwC142_C_750_420_Q90.jpg
1023616233	https://dimg03.c-ctrip.com/images/100j0f0000007975h9829_C_750_420_Q90.jpg
1023616233	https://dimg03.c-ctrip.com/images/100t0f000000793c82632_C_750_420_Q90.jpg
1023616233	https://dimg03.c-ctrip.com/images/10090f000000795pw0DE0_C_750_420_Q90.jpg
1023616233	https://dimg03.c-ctrip.com/images/10080e000000784ka8305_C_750_420_Q90.jpg
1023616233	https://dimg03.c-ctrip.com/images/100g0d0000006tl366454_C_750_420_Q90.jpg
1023616233	https://dimg03.c-ctrip.com/images/10070f000000793s9FAD7_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/100w0h0000008oozy089C_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/100l0f0000007jq23ADAB_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/100u0h0000008x0ltE878_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/100k0h0000008rq9eDB54_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/100b0g00000087r423881_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/100j0h0000008patp7AB3_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/10040f0000007gonxCEEF_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1022963926	https://dimg03.c-ctrip.com/images/100a0g00000086sko031F_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/100910000000p33mj2A94_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/fd/tg/g5/M07/EB/44/CggYr1cphSGAG7EDABOqscYYgaU096_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/fd/tg/g2/M03/88/8E/Cghzf1WwuOCAIuYfABgF1K1ff2g584_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/88/80/CghzgFWwtMiAL8dPABWj77Z0ZEU203_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/86/9D/CghzgFWwpDOARVK2AAsH6G1OsHs936_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/100110000000owmud4DD1_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/fd/tg/g5/M09/F4/AA/CggYsVcpkQmAb_szABBK3wiYWJE568_C_750_420_Q90.jpg
1024280515	https://dimg03.c-ctrip.com/images/10050y000000luriiDD40_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100w0h0000008oozy089C_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/10090q000000gohvrA50C_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100b0g00000087r423881_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100d0s000000hk13a0EEC_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/10030g00000087q2h6149_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100h0h0000008p9zjD429_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100a0g00000087pk666A7_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100v0t000000im8lb3B1D_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100d0e00000071touFBA9_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/1006090000003xpht4E13_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100u0k000000bhz28771D_C_750_420_Q90.jpg
1023450960	https://dimg03.c-ctrip.com/images/100g0h0000008oohc4BB5_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100a0g00000087pk666A7_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/10030g00000087q2h6149_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100b0g00000087r423881_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100d0e00000071touFBA9_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100g0h0000008oohc4BB5_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100u0k000000bhz28771D_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/1006090000003xpht4E13_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100w0h0000008oozy089C_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/10090q000000gohvrA50C_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100d0s000000hk13a0EEC_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100v0t000000im8lb3B1D_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/100h0h0000008p9zjD429_C_750_420_Q90.jpg
1021998953	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/100r0j000000a151zFF80_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/10040m000000dakz149CE_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/100h0m000000dpxxd8299_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g2/M03/88/8E/Cghzf1WwuOCAIuYfABgF1K1ff2g584_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/88/80/CghzgFWwtMiAL8dPABWj77Z0ZEU203_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/86/9D/CghzgFWwpDOARVK2AAsH6G1OsHs936_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g1/M0A/C8/25/CghzflWwuSiART_UAArUhyqm2j8835_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g1/M07/7A/86/CghzfVWwtQGASbOQACVEQO4RKn8049_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g1/M05/C5/DD/CghzflWwpEWALEh1ABDQ-icQmAY419_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g1/M01/78/B3/CghzfVWwpJSAPqVMAAFieRpJhlo068_C_750_420_Q90.jpg
1018710340	https://dimg03.c-ctrip.com/images/fd/tg/g1/M08/79/68/CghzfVWwqWOAVIJCABsr-Jvcx5s826_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100u0h0000008x0ltE878_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100d0k000000bhzv5404C_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100o0h0000008tu2yE77E_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100j0k000000bizzj908F_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100w0m000000dkj6o6665_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100k0m000000e206361AF_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100p090000003r2pc00AF_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100t090000003r3mk11DC_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100p0e00000078uynCA5A_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/10030e00000078v44D59E_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/10020e00000078ue711F0_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/10080e00000078tue66E6_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100s0p000000fpiwl9925_C_750_420_Q90.jpg
1024126518	https://dimg03.c-ctrip.com/images/100w11000000r34y95DF6_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100o0h0000008tu2yE77E_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100j0k000000bizzj908F_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/10040m000000de6qdAD97_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100u0h0000008x0ltE878_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100d0k000000bhzv5404C_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100w0m000000dkj6o6665_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100k0m000000e206361AF_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/10010g0000008nrkn6594_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100f0o000000eokpr1F28_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100h0o000000eqh6iBF7B_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100n0o000000eo7ncCDCB_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100w0r000000hh6g1013C_C_750_420_Q90.jpg
1024149421	https://dimg03.c-ctrip.com/images/100s10000000oan0446FF_C_750_420_Q90.jpg
4150555	https://dimg03.c-ctrip.com/images/100n0g0000008ntzvFFCF_C_750_420_Q90.jpg
4150555	https://dimg03.c-ctrip.com/images/100q0g0000007tcaiD083_C_750_420_Q90.jpg
4150555	https://dimg03.c-ctrip.com/images/10030h0000008opx52BE0_C_750_420_Q90.jpg
4150555	https://dimg03.c-ctrip.com/images/100d0e00000071touFBA9_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/100910000000p33mj2A94_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/100j0f0000007975h9829_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/100i090000003xpuwC142_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/100t0f000000793c82632_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/10090f000000795pw0DE0_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/10080e000000784ka8305_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/100g0d0000006tl366454_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/10070f000000793s9FAD7_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/10080s000000hlplh1D36_C_750_420_Q90.jpg
1024668652	https://dimg03.c-ctrip.com/images/100c0z000000nf2md0581_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/100j0h0000008patp7AB3_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/100q0e00000076p1lFC1D_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/100w0h0000008op004CE4_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/100q070000002qq4l5D27_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/10040f0000007gonxCEEF_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/100n0h0000008op8a469A_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/fd/tg/g6/M06/0C/EE/CggYtFcYR_CAFjMpAC0xBuQBNGg380_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/100n0g0000008ntzvFFCF_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/fd/tg/g5/M05/11/D6/CggYsVcYR4aAOFMcADTtJf0qH60776_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/100o0h0000008oq2q8361_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/10050h0000008riow1769_C_750_420_Q90.jpg
1019560466	https://dimg03.c-ctrip.com/images/10080h0000008s6cs5991_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/88/80/CghzgFWwtMiAL8dPABWj77Z0ZEU203_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/fd/tg/g5/M07/EB/44/CggYr1cphSGAG7EDABOqscYYgaU096_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/100910000000p33mj2A94_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/100110000000owmud4DD1_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/fd/tg/g5/M09/F4/AA/CggYsVcpkQmAb_szABBK3wiYWJE568_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/fd/tg/g2/M07/86/9D/CghzgFWwpDOARVK2AAsH6G1OsHs936_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/10050y000000luriiDD40_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/fd/tg/g2/M03/88/8E/Cghzf1WwuOCAIuYfABgF1K1ff2g584_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/100a0l000000dbgqk0E14_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/100j0l000000d9pkcEAA0_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/100k0l000000de5aq60A6_C_750_420_Q90.jpg
1023314344	https://dimg03.c-ctrip.com/images/100c0l000000dcu0n185F_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/100j0h0000008patp7AB3_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/100q0e00000076p1lFC1D_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/100w0h0000008op004CE4_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/100q070000002qq4l5D27_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/10040f0000007gonxCEEF_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/100n0h0000008op8a469A_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/fd/tg/g6/M06/0C/EE/CggYtFcYR_CAFjMpAC0xBuQBNGg380_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/100n0g0000008ntzvFFCF_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/fd/tg/g5/M05/11/D6/CggYsVcYR4aAOFMcADTtJf0qH60776_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/100o0h0000008oq2q8361_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/10050h0000008riow1769_C_750_420_Q90.jpg
1021972528	https://dimg03.c-ctrip.com/images/10080h0000008s6cs5991_C_750_420_Q90.jpg
\.


--
-- Data for Name: travel_kind; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.travel_kind (travel_id, kind_id) FROM stdin;
2917664	1
1646440	1
1021291850	1
2223702	1
1022875352	1
1022900400	1
1740478	1
1023219218	1
1979124	1
1021232487	1
5515779	1
1020460554	1
1018632811	1
1018205338	1
1017617144	1
2918034	1
5516095	1
1936768	1
5516072	1
1655500	1
1023217846	1
1024680990	1
1024685033	1
71801	1
36838	1
1009991988	1
2556409	1
1019194061	1
1018919513	1
2632836	1
1017168449	1
1021931014	1
1011208034	1
1024942188	1
1014187071	1
1021086987	1
1014539361	1
3422942	2
2520032	2
1018965634	2
1024280216	2
1021931445	2
1024139739	2
1019686314	2
1024279184	2
1023616233	2
1022963926	2
1024280515	2
1023450960	2
1021998953	2
1018710340	2
1024126518	2
1024149421	2
4150555	2
1024668652	2
1019560466	2
1023314344	2
1021972528	2
\.


--
-- Data for Name: travel_kind_instance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.travel_kind_instance (kind_id, kind_name) FROM stdin;
1	人文古迹
2	自然名胜
\.


--
-- Data for Name: travel_product; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.travel_product (travel_id, travel_title, travel_score, num_people, travel_price, travel_date) FROM stdin;
2917664	美国夏威夷7日5晚自由行·『性价比甄选』【酒店自选|航班多选】5晚连住 酒店超优价|拔草恐龙湾&钻石头山&大风口&珍珠港|首府檀香山 威基基海滩 经典行程 初游打卡	4.46	477	6767	2020-07-18
1979124	美国拉斯维加斯+夏威夷自由行·9日往返 拉斯进夏出 含内陆机票 精选热销国际品牌酒店	4.47	3	60000	2020-07-18
1646440	夏威夷11日9晚自由行·『醉深度』【4+5晚双酒店|中文接送机】徒步钻石头山 ins朋友圈大片拍摄地|恐龙湾浮潜 深入海底世界|冲浪天堂 哈雷伊瓦小镇|古兰尼侏罗纪世界|品尝当地人in的美食『超全攻略玩法』	4.47	66	43122	2020-07-18
1021291850	美国夏威夷8日6晚自由行(5钻)·【网红款】『粉红宫殿酒店』可升级畅游全岛‖特色花环接机｜珍珠港+环岛观光｜波利尼西亚文化村｜恐龙湾浮潜｜邂逅海豚or探索侏罗纪｜特色虾餐	4.38	2	32915	2020-07-18
5515779	美国洛杉矶市+拉斯维加斯+夏威夷10日8晚自由行·精选热销酒店 地面交通全含 	4.41	2	5465	2020-07-18
1021232487	美国夏威夷8日6晚自由行·【亲子升级优选】航班酒店任选·特色花环接机|珍珠港+大环岛经典游览|波利尼西亚文化村|恐龙湾浮潜|邂逅海豚or探索侏罗纪2选1|网红虾餐	4.4	2	33009	2020-07-18
1020460554	美国夏威夷7日5晚自由行·【无需攻略·轻松游】打卡之选珍珠港、恐龙湾、钻石头山·经典环岛+酒店多选	4.48	10	41128	2020-07-18
5516095	美国洛杉矶市+拉斯维加斯+夏威夷12日10晚自由行·精选国际品牌酒店 夏威夷当地散拼 玩乐大峡谷直升飞机 迪士尼/环球影城一日游	4.41	25	7015	2020-07-18
1018632811	美国夏威夷8日6晚自由行·【懒人出游|3日当地游 珍珠港+小环岛+大环岛】经典行程全含|游览文艺小镇哈雷伊瓦 都乐菠萝园品尝甜蜜 网红大排档虾餐|A线 自选6晚酒店住宿 自由自在随心游	4.42	5	9302	2020-07-18
5516072	美国洛杉矶市+拉斯维加斯+夏威夷11日9晚自由行·精选热销酒店	4.4	6	6451	2020-07-18
1024680990	美国夏威夷+洛杉矶9日7晚自由行·【4晚夏威夷+3晚洛杉矶|一岛一城】热情海岛plus天使之城|威基基蔚蓝海岸 恐龙湾浮潜 打卡经典环岛游|环球影城冒险旅程 网红墙地标街拍 重走爱乐之城 玩家新宠天空观景台	4.45	30	21521	2020-07-18
1018205338	美国夏威夷7日5晚自由行(5钻)·『酒店控』四季-亲子推荐|太平洋度假酒店-与鱼群共进早餐|推荐珍珠港感受历史 欧胡环岛打卡 Alamo租车包可选|升级大岛茂宜一日游	4.46	4	48634	2020-07-18
1017617144	美国夏威夷7日5晚自由行·【新品推荐】直飞/转机·多酒店选择·可升级畅游全岛套餐 特色花环接机|珍珠港+大环岛经典游览|波利尼西亚文化村|恐龙湾浮潜|邂逅海豚/探索侏罗纪2选1|网红虾餐	4.37	2	43739	2020-07-18
2918034	美国夏威夷9日7晚自由行·【深度游·玩转欧胡】威基基区域酒店·【可选择升级环岛套餐】花环接机|珍珠港+大环岛经典游览|波利尼西亚文化村|恐龙湾浮潜|邂逅海豚or探索侏罗纪2选1|网红虾餐·体验多彩夏威夷	4.36	46	25858	2020-07-18
1936768	美国夏威夷9日7晚自由行·多车组 双酒店 自驾游	4.45	11	23546	2020-07-18
1655500	美国夏威夷12日10晚自由行·【悠长假期】双酒店·经典环岛游+接送机	4.44	67	46251	2020-07-18
1024685033	美国夏威夷+洛杉矶10日8晚自由行·【3晚欧胡+2晚大岛+3晚洛杉矶|夏进洛出】大岛直飞洛杉矶 不走回头路|檀香山经典游 古兰尼寻梦侏罗纪 大岛火山国家公园|好莱坞电影梦 加州迪士尼乐园 洛杉矶一地深度	4.48	102	46512	2020-07-18
1740478	美国洛杉矶市+拉斯维加斯+夏威夷5-35日自由行·5-35日往返 洛进夏出 含内陆航班	4.5	69	8964	2020-07-18
2223702	美国夏威夷+日本东京6-30日自由行·回程东京可停留 热情夏威夷+潮流东京 火山徒步|雪山观星 阳光沙滩|东瀛风情	4.5	49	8663	2020-07-18
71801	日本东京5日自由行· 【樱花祭 4月立减100/单】热款赏樱之旅 4晚核心酒店连住 Go！东京购 即刻入伙 “FOURTRY”潮流集合营 富士急乐园恐怖鬼屋节目同款 樱花树下晴空树 目黑川遇见唯美夜樱 	4.49	21303	17067	2020-07-18
36838	日本东京6日自由行·【樱花祭】富士山下品樱吹雪 东京赏樱名录 5晚核心商圈连住杉并动漫博物馆 日漫迷福利 海贼王主题乐园 大机动战士独角兽高达变身 宫崎骏三鹰美术馆龙猫/千与千寻经典回归	4.5	8115	17362	2020-07-18
1009991988	日本东京4日自由行·【樱花祭】粉雪时节 3晚市区连住 东京百选赏樱名所 见晴之丘#六本木下俯瞰天空之城| 国立新美-森林中的展览 吉卜力宫崎骏造梦时代 原宿表参道涩谷 潮流小众社区 	4.54	1266	16786	2020-07-18
2632836	日本东京+大阪7日自由行·【双城 火爆线路】·东京3晚+大阪3晚| 超in银座购物世界&登顶东京铁塔·梅田邂逅360度大阪夜景·美食天堂·岚山怀旧火车浪漫隧道	4.59	4980	12445	2020-07-18
1014187071	日本大阪+京都+东京8日自由行·【经典三城】大阪2晚+京都2晚+东京3晚·阪进东出经典线路 | 连宿2晚京都·清水寺夜游&千年古都艺伎回忆 奈良神鹿 经典必游	4.53	2222	13544	2020-07-18
2556409	日本东京+迪士尼（Disney）6日自由行·【寒假春节亲子预售】 前2晚精选迪士尼酒店 可选迪士尼酒店到市区酒店接驳 圣诞新年节 魅力魅力米妮 大白欢乐市集 家庭亲子时光 童心复刻 惊魂古塔 明日乐园 刺激心跳 	4.58	7057	18064	2020-07-18
1019194061	日本东京+镰仓市5日自由行·亲爱的热爱的城市『现』男友打卡| 湘南海岸边1晚镰仓王子酒店·灌篮高手巡礼 古朴江之电穿越褪色的日系街道 怀念的热血青春 车站旁奔跑的棒球少年 海街的年轻浪漫	4.6	216	17570	2020-07-18
1018919513	日本东京+箱根6日自由行·【樱花祭】前2晚箱根温泉旅馆 深度放松 芦之湖湖上鸟居 赏富士山美樱  3晚东京市区连住 一段旅程·双重体验 抛开喧嚣 私享治愈之旅 #百选温泉系列#	4.59	135	18524	2020-07-18
1017168449	日本东京7日自由行·东瀛深度游 7天6晚探游之旅 热门商圈连住东京美食探店 网红寿喜锅 情迷海贼王乐园 可选包车畅游富士/镰仓/横滨·畅游周边网红茨城 漫天粉蝶花 Find my Tokyo	4.58	1573	18008	2020-07-18
1021931014	日本东京5日自由行(4钻)·超人气酒店精选 格拉斯丽/新宿华盛顿/品川王子等核心随心选 4晚连住 东京购物把 潮流买手 时尚尖货 欢度东京打折季	4.57	27	17204	2020-07-18
1021086987	日本大阪+东京8日自由行·双城连游·大阪3晚+东京4晚·阪进东出 | 打卡大阪城公园·祈福京都古寺·奈良寻萌鹿 | 浅草寺祈福·潮流网红INS打卡	4.55	273	13541	2020-07-18
1011208034	日本东京+箱根5日自由行·【樱花祭】湖景樱花神社中间1晚箱根温泉 网红私汤任选|可加购箱根包车2日游或2日周游券 出行无忧|品温泉观富士山美景芦之湖海盗船 浪漫邂逅温泉季 	4.55	618	17860	2020-07-18
1014539361	日本东京+富士河口湖町2-15日自由行·【温泉】温泉旅馆1晚起住·自由随心搭配 富士山观景·忍野八海·御殿场奥莱行程推荐	4.53	302	16424	2020-07-18
1024942188	日本东京+轻井泽町6日自由行(4钻)·【滑雪】前2晚轻井泽王子酒店度假村 私家雪场雪夜漫游 目之所及皑皑白雪与浩瀚星空 超便利王子购物广场 雪景小木屋 唯美冬季	4.55	11	17928	2020-07-18
3422942	丽江+大理6日自由行·【口碑人气款·网红特惠】丽江3晚+大理2晚·热门商圈古城特色客栈OR国际度假酒店可选丨玉龙雪山VS洱海·打卡双古城丨精选一日游/门票可选·嗨！假期~	4.57	5643	3119	2020-07-18
2520032	俄罗斯圣彼得堡+莫斯科自由行·8-9天7晚『金秋童话』【圣彼得堡4晚+莫斯科3晚】华丽琥珀宫·普希金咖啡馆·打卡宫廷古典网红超市·精神象征红场|可选城市通票+1日包车体验+WIFI翻译机	4.56	361	5164	2020-07-18
1024280216	俄罗斯莫斯科7-8日6晚自由行(4钻)·【地铁漫游莫斯科】深度探索俄罗斯的艺术与历史·可选金环小镇/坦克博物馆/沙皇庄园/市内包车一日游/wifi翻译器 国内境外皆可出发	4.49	2	4612	2020-07-18
1019686314	俄罗斯莫斯科+谢尔盖耶夫镇+圣彼得堡8日6晚自由行(4钻)·【经典双城+4钻酒店】『可选7日包车套餐含四宫门票』探索华丽圣彼得堡及红色首都·多人均价更优惠|可选WIFI翻译机	4.48	23	5321	2020-07-18
1024139739	俄罗斯圣彼得堡+摩尔曼斯克+莫斯科10-11日9晚自由行·【梦幻雪国经典双城+北纬69度极光秘境】『全球极光榜单目的地』『限时特惠·立减50/人』列宁号破冰船·精神象征红场·北极圈内品帝王蟹	4.47	14	6451	2020-07-18
1024279184	俄罗斯圣彼得堡+莫斯科8-9日7晚自由行(4钻)·『双城深度』【圣彼得堡4晚+莫斯科3晚】华丽琥珀宫·普希金咖啡馆·神奇涅瓦河开桥仪式·精神象征红场|可选城市通票+1日包车体验+WIFI翻译机	4.55	3	6457	2020-07-18
1023616233	俄罗斯圣彼得堡+莫斯科自由行·8-9天7晚『双城深度』【圣彼得堡3晚+莫斯科4晚】华丽琥珀宫·普希金咖啡馆·神奇涅瓦河开桥仪式·精神象征红场|可选浪漫芭蕾+各宫门票+城市通票+1日包车体验+WIFI翻译机	4.55	2	4651	2020-07-18
1024280515	俄罗斯莫斯科5-6日4晚自由行(4钻)·『慢游首都』【国内俄罗斯皆可始发】深度探索俄罗斯的艺术与历史·漫游艺术地铁·壮观红场·普希金故居·华丽图兰朵餐厅·可选金环小镇/沙皇庄园包车一日游	4.49	2	5623	2020-07-18
1023450960	俄罗斯莫斯科7-8日6晚自由行·【金秋盛景莫斯科】深度探索俄罗斯的艺术与历史·可选金环小镇/坦克博物馆/沙皇庄园/市内包车一日游/wifi翻译器 国内境外皆可出发	4.49	2	5134	2020-07-18
1021998953	俄罗斯莫斯科7-8日6晚自由行·【一城深度】『3+3晚可变更酒店体验』深度探索俄罗斯的艺术与历史·漫游艺术地铁·壮观红场·普希金故居·华丽图兰朵餐厅·可选套娃产地金环小镇/沙皇庄园包车一日游 国外境外皆可出发	4.49	1	6214	2020-07-18
1019560466	俄罗斯莫斯科+圣彼得堡+索契10日8晚自由行·【双城+黑海明珠】【含2段内陆机票】夏季热情海滨·面朝大海·春暖花开·冬季滑雪疗养温泉·可品世界美食|可选WIFI翻译机	4.55	2	4650	2020-07-18
1022875352	美国夏威夷+日本东京9日自由行(4钻)·夏威夷4晚+东京3晚阳光沙滩 特色海湾酒店 热辣草裙舞 茂宜欧胡双岛游 恐龙湾/钻石头山/大风口 上山下海历险记 PLUS东京富士山/迪士尼 潮流东京塔购物探店 美味日式料理	4.5	3	15259	2020-07-18
1022900400	美国夏威夷+东京迪士尼乐园+日本东京10日自由行(4钻)·夏威夷4晚+东京迪士尼2晚+东京市区2晚 阳光沙滩 特色海湾酒店  茂宜欧胡双岛游   PLUS东京迪士尼亲子畅玩 潮流东京塔购物探店 美味日式料理	4.54	10	15558	2020-07-18
1023219218	美国夏威夷5日3晚自由行(4钻)·【逛吃买】【品牌酒店入住】【低税购物】【美式大餐】短时出游 热辣海岛	4.35	6	12812	2020-07-18
1023217846	美国夏威夷5日3晚自由行(5钻)·【打卡·太平洋】【精选酒店】【低税购物】彩虹之州 天堂原乡 可升级双岛·火山一日游	4.35	4	44039	2020-07-18
1018965634	俄罗斯莫斯科3-30日自由行·【国内境外均可始发·含往返机票】『一城深度』 一晚起订·可选丰富玩乐或包车|WIFI翻译机	4.5	37	3940	2020-07-18
1021931445	俄罗斯莫斯科+摩尔曼斯克4-30日自由行·【红色首都+极光之城】冬季推荐选择狗拉雪橇·雪地摩托·麋鹿乐园·品尝帝王蟹·核动力破冰船·极光追逐·部分城市可选WIFI翻译机	4.3	5	6524	2020-07-18
4150555	俄罗斯莫斯科+圣彼得堡3-30日自由行·【经典双城】『1晚起订』·莫进圣出·奢简由人|可选丰富玩乐·WIFI翻译机	4.6	159	6500	2020-07-18
1024668652	俄罗斯圣彼得堡+莫斯科自由行·3-30天【圣进莫出】『历史与现代交融』推荐苏联记忆克宫·华丽皇室冬宫和叶宫·世界杯球场|可选多种门票·中文电子导览	4.7	8	5864	2020-07-18
1022963926	俄罗斯圣彼得堡+莫斯科+弗拉基米尔8-9日7晚自由行(5钻)·【双城+金环三镇】【内陆机票】 【可选全程包车】【1人起订，多人预订均价更优惠】|可选多种门票·WIFI翻译机	4.51	30	21253	2020-07-18
1018710340	俄罗斯莫斯科+圣彼得堡+阿联酋迪拜8日6晚自由行·【热情斯拉夫+阿拉伯风情】『每城2晚』艺术博物馆般的地铁+文艺普希金咖啡馆+浪漫芭蕾舞+华丽琥珀宫+打卡网红土豪国地标|可选WIFI翻译机	4.54	24	10014	2020-07-18
1024126518	俄罗斯圣彼得堡+莫斯科+阿塞拜疆8-9日7晚自由行·【两国初探】『含莫斯科-阿塞拜疆机票』艺术地铁漫游·华丽皇室风情·高加索风情古城·希尔万沙宫殿·火焰山|可选城市通票·四宫门票·1日包车·WIFI翻译机	4.55	28	8642	2020-07-18
1024149421	俄罗斯圣彼得堡+莫斯科+哈萨克斯坦10-11日9晚自由行·【两国初揽】『含莫斯科-阿拉木图机票』艺术地铁漫游·华丽皇室风情·伊犁山脉围绕的阿拉木图·绝景高山湖|可选城市通票·四宫门票·1日包车·WIFI翻译机	4.59	30	13578	2020-07-18
1023314344	俄罗斯莫斯科+叶卡捷琳堡7-8日6晚自由行·【首都+横跨亚欧之城】【北京/哈尔滨可直飞】【国内俄罗斯皆可始发】推荐双城世界杯球场+亚欧边界纪念碑+莫斯科艺术地铁漫游·可选金环小镇包车·WIFI翻译机	4.55	10	5764	2020-07-18
1021972528	俄罗斯莫斯科+圣彼得堡+索契10日8晚自由行·黑海之滨+索契高山滑雪|可选WIFI翻译机·可选莫-圣高铁	4.55	31	6424	2020-07-18
\.


--
-- Data for Name: travel_raider; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.travel_raider (travel_id, raider_id) FROM stdin;
\.


--
-- Data for Name: travel_stoke; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.travel_stoke (travel_id, travel_step_id, travel_copy_id, travel_step_detail) FROM stdin;
2917664	1	1	出发地—夏威夷
2917664	2	1	夏威夷檀香山
2917664	2	2	办理登机:请自行直接在出发地机场国际出发大厅办理登机<br><br>航班信息:由出发前往夏威夷（具体航班信息请在预订下一步中查看）
2917664	2	3	抵达美国，办理相关入境手续，导游接机。<br><br>温馨提示：接送机服务及以下行程仅推荐，如不需要请在下一步默认行程中，将份数更改为0，则您所预订的产品仅含机票+酒店。
2917664	2	4	夏威夷酒店通常在下午三点开始办理酒店入住手续，这段时间您也可以去威基基海滩散散步，或者游游泳，或者只是躺在沙滩上晒晒太阳，打个小盹，或者租冲浪板去随波逐浪。<br> 晚餐：敬请自理<br> 晚上您可以去享用美食，在熙熙攘攘的Kalakaua大街上有各种餐厅和酒吧，并可以欣赏街头艺术，使您流连忘返。 
2917664	3	1	夏威夷檀香山
2917664	3	2	（当天行程为【夏威夷珍珠港半日游】，客人可根据喜好选择日期） <br>温馨提醒：选择此行程日期请勿与航班日期重叠。
2917664	3	3	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
2917664	4	1	夏威夷檀香山
2917664	4	2	您可选择漫步于喧闹的街市，领略当地的街头文化；或者和海风、沙滩、阳光来上一次亲密接触，让自己的身体学着放松和享受！<br>晚餐：敬请自理
2917664	4	3	（当天行程为【夏威夷小环岛半日游】，客人可根据喜好选择日期） <br>温馨提醒：选择此行程日期请勿与航班日期重叠。
2917664	4	4	推荐餐厅【Bubba Gump Shrimp】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站
2917664	5	1	夏威夷檀香山
2917664	5	2	今天全天您可以自由安排活动
2917664	5	3	推荐自选活动：<br>【波利尼西亚文化中心】<br>【套餐简介】：<br>1、接送+演出+自助晚餐：畅游七个村落、独木舟水上舞蹈音乐表演、体验圣殿访客中心之旅、欣赏“HA～生命之歌”、自助餐每日名额有限。<br>自助晚餐菜单：新鲜水果，素菜沙拉（切碎的奶酪，胡萝卜条，橄榄，黄瓜片，小玉米，葵花籽，熏肉，菠萝块），当地特色hukilau沙拉，日本酱汤，甘蓝猪肉卷，炸鸡，红烧鲯鳅鱼，茂宜混合蔬菜，肉汁土豆泥，米饭，菠萝面包，巧克力/椰子蛋糕，百事可乐，咖啡和凉茶（以餐厅实际提供的菜色为准）。<br>2、接送+演出+阿里鲁奥餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、阿里鲁奥自助晚餐 、“HA～生命之歌”中排座位。<br>3、接送+演出+大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、大使牛肋排自助晚餐  、“HA～生命之歌”前排座位、“HA～生命之歌”特别导览。<br>4、接送+演出+鲁奥大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、阿里鲁奥自助晚餐、“HA～生命之歌”特别导览、“HA～生命之歌”前排座位。<br>5、接送+演出+超级大使套餐：畅游七个村落、各村落表演VIP专属座位、专属独木舟村落游、独木舟水上舞蹈音乐表演、VIP专属座位、特制夏威夷贝壳花环、夏威夷花环欢迎式、个人专属导游园区导览、精致餐点、后台参观、“HA～生命之歌” VIP贵宾席、圣殿访客中心之旅、表演节目DVD纪念光盘。<br>注意：<br>1）由于该行程抵达文化村的时间在15：00-15：30左右，且每个村落的表演时间都不一样，所以可能无法带您逛完所有的村落，用餐时间也会根据每天的人数等调整。请您谅解。<br>2）鲁奥大使套餐的用餐时间比其他套餐的用餐时间早30分钟左右，所以参观部落村及观看演出的时间会减少。请您谅解。
2917664	5	4	推荐自选活动：<br>【大岛一日游】<br>特色景点：<br>【夏威夷大岛：在热带滑雪】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br>【夏威夷火山国家公园：看火山熔岩】<br>来到大岛，夏威夷火山国家公园是必游景点。这里坐落着两座活火山茂纳洛亚火山（Mauna Loa）和基拉韦厄（Kilauea），毁灭与新生在此并存。站在巨大的火山口旁，看通红炽热的岩浆在火山湖中流淌，堪称大自然奇观。穿过历史悠久的熔岩通道，尽头又是一片葱郁繁茂的热带雨林，颇有柳暗花明又一村之感。<br>【希洛海湾黑沙滩：邂逅玳瑁和绿海龟】<br>大多数人对于夏威夷的印象是碧海白沙，而大岛由于火山活动频繁，造就了这里奇特的黑沙滩。光脚漫步在纯黑色的沙地上，触感竟然分外细腻柔软。入眼所及，清冽的海水和锃亮黝黑的岩石在阳光的照耀下形成鲜明有趣的对比，由于黑色的沙子能更好的吸收太阳光，趴在沙滩上进行日光浴也是十分悠闲愉快的享受。当地的两种珍惜动物——玳瑁和绿海龟也会时常出没此地晒太阳，快来与它们邂逅吧。<br>【彩虹瀑布：对彩虹许愿】<br>彩虹瀑布由左、右两道水流交汇而成，犹如一匹白练般从岩石顶端倾泻而下，落入水潭中激起层层水雾。再加上四周青翠茂盛的热带植物映衬，景色怡人。等到天气晴好时，瀑布的水雾在阳光的折射下形成了一道灿烂的彩虹天桥，横架在水潭上方，又给这幅山水画卷添上了绚丽多彩的一笔。
2917664	5	5	推荐餐厅【Roy's Waikiki】Roy's 餐厅是夏威夷有名的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。丰盛大餐配上优质的服务，不容错过，建议提前1-2天订位。交通<br>：可乘坐公交8、19、20、23、42至Kalia Rd + Saratoga Rd站下车，向东南方步行10分钟即可。<br>
2917664	6	1	夏威夷-出发地
2917664	6	2	今天全天您可以自由安排活动<br>
2917664	6	3	推荐自选项目：<br>【古兰尼牧场】<br>【270分钟体验活动】<br>1、山谷体验之旅：游览令人叹为观止的卡阿瓦山谷ka'a'awa，体验户外的牧场，农田，观好莱坞大片外景拍摄地如：侏罗纪公园Jurassic Park，迷失Lost，哥斯拉Godzilla等。<br>2、深山体验之旅：一起探索古兰尼丰富的历史和传统，乘坐六轮瑞士军用吉普车去探索原始的哈基普雾山谷Hakipu'u，沿着丛林小道通过河床和陡峭的山丘，探险热带丛林。<br>3、体验之旅（待定）：古兰妮牧场即将更新体验套餐，敬请期待
1021291850	4	3	【恐龙湾】<br>恐龙湾Hanauma Bay是来夏威夷的游客喜欢去的潜水的地方之一。水浅，浪小，鱼多，风景美丽，那里有各种天然的珊瑚礁石和热带鱼类。恐龙湾是海底死火山，火山口的一面受海浪万年不变的拍击而倒塌，变成象马蹄的形状，所以又被戏称为马蹄湾。恐龙湾是中国人给起的名字，因为从海湾的一头远远望去，恐龙湾就像一头窝在海水中的恐龙。
1021291850	4	4	特色虾餐
1022875352	9	4	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。
2917664	6	4	推荐自选项目<br>【恐龙湾浮潜】<br>恐龙湾Hanauma Bay是来夏威夷的游客喜欢去的潜水的地方之一。水浅，浪小，鱼多，风景美丽，那里有各种天然的珊瑚礁石和热带鱼类。恐龙湾是海底死火山，火山口的一面受海浪万年不变的拍击而倒塌，变成象马蹄的形状，所以又被戏称为马蹄湾。恐龙湾是中国人给起的名字，因为从海湾的一头远远望去，恐龙湾就像一头窝在海水中的恐龙。<br>详细行程：<br>07：00-08：00 夏威夷威基基区域酒店拼车接送服务。<br>08：00-11：00 到达恐龙湾后，客人自行下车购买门票。但在游玩前需看一部关于恐龙湾形成与保护的纪录片，因为恐龙湾是国家自然保护区。<br>11：00-11：30 离开恐龙湾（恐龙湾有严格的时间规定，请客人按照司机所要求的时间准时上车，超时无法等待，需要客人自费解决交通问题，请谅解！）。                                                                                                                                           <br>11：30-12：15 抵达威基基区域的酒店。
2917664	6	5	推荐餐厅【Fook Yuen Seafood Restaurant 】距离威基基海滩不远，餐厅很火爆，尤其受国人欢迎，饭点经常需要等位。味道是熟悉的中餐味道，服务也很不错，招牌的龙虾新鲜美味、选择很多。
2917664	7	1	上海
2917664	7	2	由导游安排送机。 
2917664	7	3	体验过夏威夷的热情。今天前往机场，乘机返回出发地。（具体航班信息请在预订下一步中查看） 
2917664	7	4	上海
2917664	7	5	抵达上海，结束了此次美妙的夏威夷之旅！ 
2917664	7	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1646440	1	1	出发地_夏威夷
1646440	2	1	夏威夷
1646440	2	2	办理登机:请自行直接机场国际出发大厅办理登机<br><br>航班信息:由出发地前往夏威夷（具体航班信息请在预订下一步中查看）<br><br>晚餐：飞机上<br><br>第二天早餐:飞机上<br><br>
1646440	2	3	抵达美国，办理相关入境手续，导游接机。<br>温馨提醒：接送机服务仅限入住威基基区域酒店客人选择。
1646440	2	4	可自行选择入住酒店。<br>温馨提示：根据国际惯例，酒店入住时间为当地时间下午3点。
1646440	2	5	三餐敬请自理
1646440	3	1	夏威夷
1646440	3	2	全天自由活动。
1646440	3	3	今天，推荐您去珍珠港走走逛逛吧。您可选择购买通票或者包车前往。<br>温馨提醒：选择此行程日期请勿与航班日期重叠。
1646440	3	4	同前一天入住酒店
1646440	3	5	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。<br>交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
1646440	4	1	夏威夷
1646440	4	2	全天自由活动
1646440	4	3	今天，推荐您前往游览欧胡岛东岸，打卡各个经典景点。您可选择散拼团或者包车前往。<br>温馨提醒：选择此行程日期请勿与航班日期重叠。
1646440	4	4	同前一天入住酒店
1646440	4	5	三餐敬请自理。<br>推荐餐厅【Roy's Waikiki】Roy's 餐厅是夏威夷有名的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。丰盛大餐配上优质的服务，不容错过，建议提前1-2天订位。<br>交通：可乘坐公交8、19、20、23、42至Kalia Rd + Saratoga Rd站下车，向东南方步行10分钟即可。
1646440	5	1	夏威夷
1646440	5	2	全天自由活动
1646440	5	3	推荐活动：【古兰尼牧场】<br>【90分钟活动自选】<br>1、山谷体验之旅：游览令人叹为观止的卡阿瓦山谷ka'a'awa，体验户外的牧场，农田，观好莱坞大片外景拍摄地如：侏罗纪公园Jurassic Park，迷失Lost，哥斯拉Godzilla等。<br>2、深山体验之旅：一起探索古兰尼丰富的历史和传统，乘坐六轮瑞士军用吉普车去探索原始的哈基普雾山谷Hakipu'u，沿着丛林小道通过河床和陡峭的山丘，探险热带丛林。<br>3、海洋体验之旅：乘坐巴士参观种植了各种不同的热带水果的茉莉依花园，随后游览者瓦胡岛上保存得完好的古代夏威夷鱼塘，享受美丽和宁静的环境，再从神秘岛出发乘坐双体船游览卡内奥赫海湾Kaneohe Bay，欣赏背面的怡人景色。双体船游览活动周日和美国公众假期不开放。<br>【3小时神秘岛活动】<br>神秘岛海滩是一个僻静的私人海滩，是一个放松自我，舒缓压力的好去处。提供不同的海上娱乐设施如划皮艇，划独木舟，以及立浆冲浪等，还提供不同球类活动如沙滩排球，羽毛球，乒乓球等。
1646440	5	4	同前一天入住酒店（或可自行选择其他入住酒店）
1646440	5	5	三餐敬请自理<br>推荐餐厅【California Pizza Kitchen】美国有名披萨连锁店，起源于加利福尼亚的比弗利山庄，已有近30年的历史。饮料可以免费续杯。交通：可乘坐公交2L、22、E路Kalakaua Ave + Opp Seaside Ave站下车即可。
1646440	6	1	夏威夷
1646440	6	2	全天自由活动。今天推荐您去火山岛（大岛），除了阳光沙滩、椰林海浪...独特的火山地貌熔岩，也是夏威夷有别于其他海岛的标签。
1646440	6	3	推荐行程【大岛一日游】：到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br>由于大岛路况复杂，建议您参加1日游行程，从檀香山出发含岛间机票。<br><br>早餐、午餐、晚餐敬请自理。
1646440	6	4	同前一天入住酒店（或可自行选择其他入住酒店）
1646440	6	5	推荐餐厅【Fook Yuen Seafood Restaurant 】距离威基基海滩不远，餐厅很火爆，尤其受国人欢迎，饭点经常需要等位。味道是熟悉的中餐味道，服务也很不错，招牌的龙虾新鲜美味、选择很多。
1646440	7	1	夏威夷
1646440	7	2	全天自由活动。
1022875352	9	3	新宿西口（平成观光候车室）<br>地址：東京都新宿区西新宿１－２１－１１　山銀ビル（bill)４F <br>集合时间：08:15
1022875352	9	5	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>搭乘旅游巴士返回东京新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
1646440	7	3	今天全天您可以自由安排活动，或选择其他丰富的当地活动。<br>推荐活动：【波利尼西亚文化中心】<br>【套餐简介】：<br>1、接送+演出+自助晚餐：畅游七个村落、独木舟水上舞蹈音乐表演、体验圣殿访客中心之旅、欣赏“HA～生命之歌”、自助餐每日名额有限。<br>自助晚餐菜单：新鲜水果，素菜沙拉（切碎的奶酪，胡萝卜条，橄榄，黄瓜片，小玉米，葵花籽，熏肉，菠萝块），当地特色hukilau沙拉，日本酱汤，甘蓝猪肉卷，炸鸡，红烧鲯鳅鱼，茂宜混合蔬菜，肉汁土豆泥，米饭，菠萝面包，巧克力/椰子蛋糕，百事可乐，咖啡和凉茶（以餐厅实际提供的菜色为准）。<br>2、接送+演出+阿里鲁奥餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、阿里鲁奥自助晚餐 、“HA～生命之歌”中排座位。<br>3、接送+演出+大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、大使牛肋排自助晚餐 、“HA～生命之歌”前排座位、“HA～生命之歌”特别导览。<br>4、接送+演出+鲁奥大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、阿里鲁奥自助晚餐、“HA～生命之歌”特别导览、“HA～生命之歌”前排座位。<br>5、接送+演出+超级大使套餐：畅游七个村落、各村落表演VIP专属座位、专属独木舟村落游、独木舟水上舞蹈音乐表演、VIP专属座位、特制夏威夷贝壳花环、夏威夷花环欢迎式、个人专属导游园区导览、精致餐点、后台参观、“HA～生命之歌” VIP贵宾席、圣殿访客中心之旅、表演节目DVD纪念光盘。<br>注意：<br>1）由于该行程抵达文化村的时间在15：00-15：30左右，且每个村落的表演时间都不一样，所以可能无法带您逛完所有的村落，用餐时间也会根据每天的人数等调整。请您谅解。<br>2）鲁奥大使套餐的用餐时间比其他套餐的用餐时间早30分钟左右，所以参观部落村及观看演出的时间会减少。请您谅解。<br><br>早餐、午餐、晚餐敬请自理。
1646440	7	4	同前一天入住酒店（或可自行选择其他入住酒店）
1646440	7	5	三餐敬请自理<br>推荐餐厅【Roy's Waikiki】Roy's 餐厅是夏威夷有名的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。丰盛大餐配上优质的服务，不容错过，建议提前1-2天订位。<br>交通：可乘坐公交8、19、20、23、42至Kalia Rd + Saratoga Rd站下车，向东南方步行10分钟即可。
1646440	8	1	夏威夷
1646440	8	2	全天自由活动。今天推荐您去茂宜岛，浪漫的蜜月胜地，众多明星的婚礼蜜月地，自然不可错过。
1646440	8	3	推荐活动：【茂宜岛一日游】：以山谷的秀丽而著称茂宜岛，十六世纪捕鲸时期形成的捕鲸镇-LAHAINA TOWN。\\
1646440	8	4	同前一天入住酒店（或可自行选择其他入住酒店）
1646440	8	5	三餐敬请自理<br>推荐餐厅【California Pizza Kitchen】美国有名披萨连锁店，起源于加利福尼亚的比弗利山庄，已有近30年的历史。饮料可以免费续杯。<br>交通：可乘坐公交2L、22、E路Kalakaua Ave + Opp Seaside Ave站下车即可。
1646440	9	1	夏威夷
1646440	9	2	全天自由活动。
1646440	9	3	今日推荐【步道踏青】<br>钻石头山步道是ins热门景点。徒步登上钻石头山，一直深受游客的欢迎。登顶步道夏威夷语名为Le’ahi (意即钻石头山火山口)，建于1908年，最初是欧胡到海岸防御系统的一部分。1911年完工后，山顶的射击指挥部指挥着炮兵部队位于威基基和火山口外Fort Ruger 的排炮。一路步行，不但能了解火山口的地质构造，更可一窥此地与军事息息相关的历史。步道大部分是天然凝灰岩地表，夹杂诸多之字形上坡路，穿越火山口内壁的山坡，爬上陡峭的阶梯，再穿越过69米长的隧道。达顶将看到火山口边缘的军事掩体，以及 1917年建于火山口外缘的导航灯塔。\\
1646440	9	4	同前一天入住酒店（或可自行选择其他入住酒店）
1646440	9	5	三餐敬请自理<br>推荐餐厅【Fook Yuen Seafood Restaurant 】距离威基基海滩不远，餐厅很火爆，尤其受国人欢迎，饭点经常需要等位。味道是熟悉的中餐味道，服务也很不错，招牌的龙虾新鲜美味、选择很多。
1646440	10	1	夏威夷_出发地
1646440	10	2	全天自由活动。
1646440	10	3	您可选择漫步于喧闹的街市，领略当地的街头文化；或者和海风、沙滩、阳光来上一次亲密接触，让自己的身体学着放松和享受！
1646440	10	4	九晚住宿过后，您将搭乘所选航班回到温暖的家，请留意按时退房（可寄存行李游玩），提前前往机场候机。
1646440	10	5	三餐敬请自理<br>推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
1646440	11	1	出发地
1646440	11	2	导游送机。
1646440	11	3	搭乘国际航班返回国内
1646440	11	4	出发地
1646440	11	5	抵达目的地，结束此次美妙的夏威夷之旅！ 
1646440	11	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1021291850	1	1	国内出发地_夏威夷
1021291850	2	1	欧胡岛
1021291850	2	2	请至少提前3小时自行前往机场办理登机手续<br/> 抵达夏威夷后，前往办理相关入境手续并提取行李
1021291850	2	3	如不需要升级套餐，预订下一步升级选项份数为0，则您所预定的产品仅为机票+酒店套餐。自由规划行程建议您单独预订接送机服务
1021291850	2	4	抵达夏威夷，导游接机后送往当地酒店办理入住。 <br/> 1.国际航班(MU/KE/NH/OZ)早上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机  <br/> <br>2.国际航班(CA/HA)晚上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机 <br/> <br>3.美国本土国内到达的客人,请到行李提取处跟导游汇合。我们导游会穿蓝色Polo体桖举牌接机 <br/> <br>注：接机为当地散拼，可能需要等到同航班其他客人全部出来后才能出发。
1021291850	2	5	备注：<br>夏威夷酒店通常在下午15:00PM后办理入住；如您抵达酒店时无法办理入住，请客人把行李寄存在酒店后开启自由度假时光。<br/>
1021291850	3	1	欧胡岛
1021291850	3	2	上午参加：珍珠港+市区游+珠宝博物馆参观。（行程参考时间7:30am-11:30am，以接机导游给到的行程确认单为准）<br>【珍珠港】位于美国夏威夷州欧胡岛上的海港，位于该州首府檀香山西方。东距火奴鲁鲁约10公里。面积89平方公里。港区掩蔽条件好，水域回旋余地大，为世界天然良港。土著夏威夷人称珍珠港为\\
1021291850	3	3	夏威夷当地海岛珠宝展示馆参观
1021291850	3	4	波利尼西亚文化中心
1021291850	3	5	行程游览结束后驱车送往酒店。
1021291850	4	1	欧胡岛
1021291850	4	2	上午恐龙湾浮潜（含浮潜工具，门票自理）下午大环岛北岸精品游。特别包含夏威夷卡胡库风味虾餐（行程参考时间13:00pm-18:00pm，以接机导游给到的行程确认单为准）<br>
1022875352	9	6	交通：从新宿商圈可步行返回酒店。
1021291850	4	5	<br>游览欧胡岛的北岸， 这个是几乎是来自世界各地游客必去的夏威夷高人气线路，欧胡岛精华丽的海岸线，我们开车穿越帕里森林公路，一路观赏Ko'olau山脉，绿树成荫，然后来到Ko'olau山谷之中的一座悠静古庙—平等院（门票自理）。这座庙宇建于1968年，整座建筑没有一颗钉子，完整呈现了山谷空悠的自然之美，西安事变主角张学良先生和赵四女士就是葬在此处，大家可以到这里瞻仰一下这位改变中国历史的名人。离开Koolau 山脉我们会进入另一个夏威夷的Kualoa 山谷，美国总统奥巴马夫人在APPTEC会议期间就在此处宴请各国第一夫人，当你看到这山谷的时候一定会觉的似曾相识的感觉，侏罗纪公园，风语者，初恋50次和迷失都在那里拍摄的，这里是好莱坞导演的挚爱之地。之后前往 下 一站 MACADAMIANUT FARMOUTLET（夏威夷果农场），这 里你可品尝各种夏威夷土特产：火山 豆，咖啡等了解夏威 夷农产品 的种植情 况 ，增长相关 知识 。然后驾车前往KAHUKU ，在那里你可以品尝只有夏威夷才能吃到的KAHUKU甜虾之后前往北海岸北处的落日海滩，那是欧胡岛受欢迎的冲浪海滩冲浪者的天堂，是现代冲浪运动的起源地，每到冬季世界各地冲浪好手到此朝圣，并在此地一较高下，也就是世界冲浪锦标赛的官方指定比赛地点。下一站途径是总统奥巴玛喜欢的哈雷伊瓦小镇，每年回来度假，总统一家 都会 光顾这 里，展示第 一家 庭 的亲民，奥巴马女儿 喜欢那里的彩虹冰（途径）。后我们观光车会停在都乐菠萝园农场让 游客们下车拍照 ，沿途 一片农家田园风情。
1021291850	4	6	行程结束后返回酒店，晚餐自理
1021291850	5	1	欧胡岛
1021291850	5	2	当天行程为二选一 古兰尼牧场体验之旅 或者 海洋公园（海豚邂逅）
1021291850	5	3	今日游玩项目可自选（二选一） <br/> <br>古兰尼牧场：【自然与探险之旅】 <br/> <br>古兰尼牧场是每一位到夏威夷的游客都不容错过的景点之一。这里山峦叠嶂，树木葱郁，还有波光粼粼的大海和细白沙滩，清新优美的自然风光使其成为《侏罗纪公园》、《迷失》等诸多大片的拍摄地。再加上骑马、吉普车丛林越野、独木舟、双体船出海等花样繁多的娱乐项目，对于童心未泯的朋友们来说，简直就是探险大自然的不二去处。 <br/> <br>最近上演的《侏罗纪世界2》故事的中的努布拉岛，也是在夏威夷古兰尼牧场取景拍摄的。作为一个真正的侏罗纪系列影迷，如果想要去电影中的努布拉岛朝圣，想要化身电影的男主女主，亲身经历一下这个史前动物乐园，就不能错过古兰尼牧场这个好莱坞电影御用拍摄地。 <br/> <br>午餐：沙拉，韩式泡菜，鸡肉BBQ，牛肉BBQ，甜品，饭，饮料等自助餐，请以实际安排为准。 <br/> <br>【体验套餐】：安排【山谷体验之旅：游览好莱坞拍摄地】 【深山体验之旅：吉普车丛林越野】   【古代生态植物园】   午餐（如果有婴儿不能参加【深山体验之旅：吉普车丛林越野】项目公司会尽量安排【海洋体验之旅：迎风追浪】代替，如当天关闭则视客人自动放弃该行程） <br/> <br>1、【山谷体验之旅：游览好莱坞拍摄地】<br>如果你是好莱坞美剧控，牧场北半部的卡阿瓦山谷一定会令你惊叹不已。这里一直是无数热门电视节目和好莱坞电影的取景地，神奇的抓印造型山脉和倒塌的大枯树干让人仿佛置身于《侏罗纪公园》紧张刺激的真实场景中，你还有机会与微缩版复活节岛摩艾石像合影，途经《迷失》中Hurley打高尔夫球的球场，看一看《哥斯拉》留下的怪兽大脚印。 <br/> <br>2、【深山体验之旅：吉普车丛林越野】<br>坐上老式的军用吉普车，沿着蜿蜒的小路和起伏的山丘，来场热带雨林穿越吧！约90分钟的车程中，充满原始热带风情的哈基普雾（Hakipuu）山谷尽收眼底。游览过程中，你还将有机会短程步行到高台，俯瞰瓦胡岛东部海岸线和古代夏威夷鱼塘的美丽风光。 <br/> <br>3、【海洋体验之旅：迎风追浪】<br>踏上双体船，游览卡内奥赫海湾（Kaneohe Bay），你将离开古兰尼主园区，从Moli’i码头登上49人的双体船驶入Kaneohe海湾。在海面上您可以将整座古兰尼山尽收眼底，同时也有机会近距离接触Mokoli’i岛（又名“草帽岛”）。如果好的话，甚至可以从船上看到鲸鱼和海龟！一定要带上您的相机哦！ <br/> <br>备注：海洋巡游活动周日和美国公众假期不开放，9岁或以下儿童必须有监护人陪同参加。 <br/> <br>4、【3小时神秘岛活动】<br>神秘岛海滩是一个僻静的私人海滩，是一个放松自我，舒缓压力的好去处，是您夏威夷之行的选项之一。我们为您提供了各式各样的设备与器具，您可以放松的与大海来一次亲密接触！<br>您只需带上泳衣，浴巾，防晒霜以及相机，我们为您准备了丰富的海上活动！神秘岛上为您免费提供了香蕉船，皮划艇，独木舟，冲浪板，沙滩排球，乒乓球，羽毛球，凉席，吊床以及更多好玩的水上活动设施。或者您可以伴着海风在吊床上休息，或乘坐玻璃底船出海寻找海龟。神秘岛上设有更衣室和淋浴，建议您携带一件用于更换的衣服和毛巾。 <br/> <br>备注:玻璃底船周日不开放。 <br/> <br>5、【古代生态植物园】<br>古代生态植物园之旅给您一个机会深入了解古代夏威夷的文化和历史。您将会经过古兰尼的Moli’i热带花园。热带花园中不仅有夏威夷本土的植物，也有世界各地的植物花卉。您将会学习第一批夏威夷人是怎样将各种植物带上岛并成功种植。参观完热带花园后，您将有机会亲自品尝植物园中的水果。 <br/> <br>备注：9岁或以下儿童必须有监护人陪同参加。 <br/> <br>夏威夷海洋公园海豚邂逅 <br/> <br>凡是预定邂逅海豚节目，凭电子确认函入园即可特别获得价值10美金的Beachboy Lanai Food court 餐券。<br>游客可站在水深齐腰的平台上观察海豚表演。海豚会与游客玩耍，亲吻游客，甚至和游客一起“舞蹈”！如果天气允许，您还可以与海豚拍照留念。 <br/> <br>海豚邂逅入场时间：10:15 am/11:45 am/13:00 pm/14:30 pm（水中时间：30分钟）
1021291850	5	4	推荐餐厅【Wolfgang's Steakhouse】<br>由Wolfgang Zwiener一手创办的牛排餐厅，他曾于名震纽约餐饮界的牛排馆Peter Luger Steakhouse工作40余年，对厨艺上从无间断的精进，让沃尔夫冈牛排馆自成立以来形成独树一帜的牛排文化，无与伦比的美味征服了无数美食爱好者的味蕾，成为美国备受推崇的牛排馆之一。
1021291850	6	1	欧胡岛
1021291850	6	2	推荐活动：<br>【大岛一日游】<br>特色景点：<br>【夏威夷大岛：在热带滑雪】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br>【夏威夷火山国家公园：看火山熔岩】<br>来到大岛，夏威夷火山国家公园是必游景点。这里坐落着两座活火山茂纳洛亚火山（Mauna Loa）和基拉韦厄（Kilauea），毁灭与新生在此并存。站在巨大的火山口旁，看通红炽热的岩浆在火山湖中流淌，堪称大自然奇观。穿过历史悠久的熔岩通道，尽头又是一片葱郁繁茂的热带雨林，颇有柳暗花明又一村之感。<br>【希洛海湾黑沙滩：邂逅玳瑁和绿海龟】<br>大多数人对于夏威夷的印象是碧海白沙，而大岛由于火山活动频繁，造就了这里奇特的黑沙滩。光脚漫步在纯黑色的沙地上，触感竟然分外细腻柔软。入眼所及，清冽的海水和锃亮黝黑的岩石在阳光的照耀下形成鲜明有趣的对比，由于黑色的沙子能更好的吸收太阳光，趴在沙滩上进行日光浴也是十分悠闲愉快的享受。当地的两种珍惜动物——玳瑁和绿海龟也会时常出没此地晒太阳，快来与它们邂逅吧。<br>【彩虹瀑布：对彩虹许愿】<br>彩虹瀑布由左、右两道水流交汇而成，犹如一匹白练般从岩石顶端倾泻而下，落入水潭中激起层层水雾。再加上四周青翠茂盛的热带植物映衬，景色怡人。等到天气晴好时，瀑布的水雾在阳光的折射下形成了一道灿烂的彩虹天桥，横架在水潭上方，又给这幅山水画卷添上了绚丽多彩的一笔。
1021291850	6	3	亦或是什么都不做，呆坐在酒店酒吧，静静享受度假。
1021291850	6	4	推荐餐厅【Roy's Waikiki】<br>Roy's 餐厅是夏威夷的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。建议提前1-2天订位。
1021291850	7	1	欧胡岛-国内
1021291850	7	2	餐饮敬请自理，推荐夏威夷特色【poke】<br>夏威夷语中的Poke是切片的意思，将新鲜的鱼肉或其他海鲜切块与特制酱料相拌食用，是当地人喜爱的小食。
1021291850	7	3	今日您可自由安排行程<br><br>推荐【钻石头山徒步】<br>交通：搭乘3、9、23或24路公交车在Diamond Head Rd + 18th Ave站下车，沿公园指示牌即可到达<br>参考信息：周一-周日6:00-18:00开放，公园最晚进入时间为16:30。<br>          门票1美元/人，5美元/车。请以当地信息为准。<br>推荐【欢购夏威夷】<br>交通：您可步行前往阿拉莫那购物中心，体验低税费夏威夷购物之旅
1021291850	8	1	飞机上
1021291850	8	2	今天请您提前退房，如您升级行程，请于约定时间抵达与送机人员的约定地点，前往火奴鲁鲁机场，返回您温馨的家
1021291850	8	3	搭乘选定航班返回
1021291850	8	4	飞机上
1021291850	8	5	今日抵达国内，结束您的夏威夷之旅
1021291850	8	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1022875352	1	1	出发地_夏威夷
1022875352	2	1	夏威夷
1022875352	2	2	办理登机:请自行直接机场国际出发大厅办理登机<br><br>航班信息:由出发地前往夏威夷（具体航班信息请在预订下一步中查看）
1022875352	2	3	抵达美国，办理相关入境手续，<br>可自行选购接机前往酒店
1022875352	2	4	可自行选择入住酒店。<br>温馨提示：根据国际惯例，酒店入住时间为当地时间下午3点。
1022875352	2	5	敬请自理
1022875352	3	1	夏威夷
1022875352	3	2	今日可选购个珍珠港半日游，或者搭乘公共交通自由活动
1022875352	3	3	在酒店享受一个惬意的早餐
1022875352	3	4	今天，推荐您去珍珠港走走逛逛吧。
1022875352	3	5	同前一天入住酒店
1022875352	3	6	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
1022875352	4	1	夏威夷
1022875352	9	7	东京-国内
1022875352	9	8	您可以在酒店餐厅内享用丰富的自助早餐。
1022875352	4	2	推荐租车<br>欧胡岛的大部分自然景点都比较分散，所以租车不失为一个省时省力的好方法。你可以提前在网上预订，大部分的代理公司都有网上预订服务，而且网上提供优惠价格，比市价便宜很多。如果不是旺季，也可以到达机场后可以直接在租车的柜台订车。每个代理公司的具体计费方法不同，签订单之前需要仔细进行了解。<br>gaigaiff 在夏威夷开车需注意的是各个stop标志，在有此标志的地方必须停一下，不管有没有人，如果被警察逮到没停，后果不堪设想啊。在夏威夷加油是自助式的，只要和加油站店里的人说“I need gas for my car”然后告知你在第几个车位、买多少、交钱就可以了。
1022875352	4	3	此为推荐景点，可自行选购一日游
1022875352	4	4	推荐餐厅【Bubba Gump Shrimp】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站
1022875352	4	5	同前一天入住酒店
1022875352	5	1	檀香山—东京
1022875352	5	2	今天全天您可以自由安排活动
1022875352	5	3	今天全天您可以自由安排活动，或选择其他丰富的当地活动。<br>推荐活动：【波利尼西亚文化中心】<br>【套餐简介】：<br>1、接送+演出+自助晚餐：畅游七个村落、独木舟水上舞蹈音乐表演、体验圣殿访客中心之旅、欣赏“HA～生命之歌”、自助餐每日名额有限。<br>自助晚餐菜单：新鲜水果，素菜沙拉（切碎的奶酪，胡萝卜条，橄榄，黄瓜片，小玉米，葵花籽，熏肉，菠萝块），当地特色hukilau沙拉，日本酱汤，甘蓝猪肉卷，炸鸡，红烧鲯鳅鱼，茂宜混合蔬菜，肉汁土豆泥，米饭，菠萝面包，巧克力/椰子蛋糕，百事可乐，咖啡和凉茶（以餐厅实际提供的菜色为准）。<br>2、接送+演出+阿里鲁奥餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、阿里鲁奥自助晚餐 、“HA～生命之歌”中排座位。<br>3、接送+演出+大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、大使牛肋排自助晚餐 、“HA～生命之歌”前排座位、“HA～生命之歌”特别导览。<br>4、接送+演出+鲁奥大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、阿里鲁奥自助晚餐、“HA～生命之歌”特别导览、“HA～生命之歌”前排座位。<br>5、接送+演出+超级大使套餐：畅游七个村落、各村落表演VIP专属座位、专属独木舟村落游、独木舟水上舞蹈音乐表演、VIP专属座位、特制夏威夷贝壳花环、夏威夷花环欢迎式、个人专属导游园区导览、精致餐点、后台参观、“HA～生命之歌” VIP贵宾席、圣殿访客中心之旅、表演节目DVD纪念光盘。<br>注意：<br>1）由于该行程抵达文化村的时间在15：00-15：30左右，且每个村落的表演时间都不一样，所以可能无法带您逛完所有的村落，用餐时间也会根据每天的人数等调整。请您谅解。<br>2）鲁奥大使套餐的用餐时间比其他套餐的用餐时间早30分钟左右，所以参观部落村及观看演出的时间会减少。请您谅解。<br><br>早餐、午餐、晚餐敬请自理。<br><br>
1022875352	5	4	推荐餐厅【California Pizza Kitchen】美国有名披萨连锁店，起源于加利福尼亚的比弗利山庄，已有近30年的历史。饮料可以免费续杯。交通：可乘坐公交2L、22、E路Kalakaua Ave + Opp Seaside Ave站下车即可。
1022875352	5	5	同前一天入住酒店（或可自行选择其他入住酒店）
1022875352	6	1	抵达--东京
1022875352	6	2	在酒店享受悠闲的早餐
1022875352	6	3	可自行选购送机服务
1022875352	6	4	搭乘国际航班前往东京
1022875352	6	5	今日住宿因为时差问题是在飞机上度过，享受您的飞行时刻
1022875352	7	1	东京
1022875352	7	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
1022875352	7	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
1022875352	7	4	步行前往即可～
1022875352	7	5	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
1022875352	8	1	可选购富士山+河口湖一日游
1022875352	8	2	请至酒店内餐厅享用自助早餐<br>
1022875352	8	3	乘坐山手線到达上野，换乘東京メトロ銀座線到达浅草
1022875352	8	4	浅草聚乐是一家坐落在浅草寺附近的家庭式餐厅。在日本，家庭式餐厅是以家庭为客户群体的餐厅，菜单也是以各种套餐为主。这里不仅有日式料理，还有西式菜肴和中餐。强烈推荐牛肉寿喜烧天妇罗生鱼片套餐。这个菜又有寿喜烧，又有天妇罗和生鱼片。一次性把日本料理的3大菜系都给吃遍了。含税1500日元，性价比还是挺高的。s
1022875352	8	5	须贺神社位于新宿区一带，创建于1634年，因为《你的名字》而名噪一时。<br>自从电影上映之后，吸引了众多粉丝来朝圣，特别是神社前的一个十字路口，也是知名场景的取景地。<br>主要奉祀须贺大神和稻荷大神，神社内保存有珍贵的《三十六歌仙绘》，是新宿区的指定有形文化遗产。
1022875352	8	6	JR山手线/京滨东北线，滨松町站北口出，出门就可以看见塔，之后沿道路向增上寺前进，穿过增上寺即可到达，总路程步行约15分钟<br>地铁大江户线至赤羽桥站，赤羽桥口出步行约5分钟
1022875352	8	7	于 东京塔 3层，是人气动画《海贼王》的首 个大型主题公园，园内设有草帽海贼团各成员的主题活动区。 ·体验形式多种多样，有漫画展览、人物雕塑展、360°电影播放仪、VR体验，还有可以和cosplay人物互动的小游戏等。 ·公园内还设有主题餐厅和咖啡店，提供只有在这里才能吃到的特色美食；手办商店还将推出限量版的纪念品。 ·推荐香吉士为主题的“香吉士吃到饱餐厅”，只需付2000日元就可以大口吃烤肉。 TIPS 1. 日本国内购票方法：可在7-Eleven便利店购买预售票。日本以外地区的购票方法：可于官网购买预售票。 2. 主题乐园的停车场毗邻东京铁塔，停车1小时收取600日元，之后每30分钟加收300日元。停车场营业时间为9:00-22:00（21:45停止进场）。 3. 园区内全区禁止吸烟。 4. 酒类、饮品、便当类、三脚架等摄影辅助器材、一切危险物品等禁止携带入园。现场表演中请勿使用相机、摄影机、手机等纪录影像或录音。
1022875352	9	1	东京-国内
1022875352	9	2	可以享用酒店内的自助早餐，或者在便利店购买
1021232487	2	1	欧胡岛
1021232487	8	3	导游送机
1021232487	8	4	国内
1022875352	9	9	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1022875352	9	10	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1022875352	9	11	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1022875352	9	12	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1022875352	9	13	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1022875352	9	14	乘坐舒适的班机返回国内，结束本次愉快的旅途
1022875352	9	15	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1022900400	1	1	出发地_夏威夷
1022900400	2	1	夏威夷
1022900400	2	2	办理登机:请自行直接机场国际出发大厅办理登机<br><br>航班信息:由出发地前往夏威夷（具体航班信息请在预订下一步中查看）
1022900400	2	3	抵达美国，办理相关入境手续，<br>可自行选购接机前往酒店
1022900400	2	4	可自行选择入住酒店。<br>温馨提示：根据国际惯例，酒店入住时间为当地时间下午3点。
1022900400	2	5	敬请自理
1022900400	3	1	夏威夷
1022900400	3	2	早餐: 在酒店享受一个惬意的早餐
1022900400	3	3	交通: 今日可自行订购购个珍珠港半日游，或者搭乘公共交通自由活动
1022900400	3	4	今天，推荐您去珍珠港走走逛逛吧。
1022900400	3	5	同前一天入住酒店
1022900400	3	6	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
1022900400	4	1	夏威夷
1022900400	4	2	通: 推荐租车<br>欧胡岛的大部分自然景点都比较分散，所以租车不失为一个省时省力的好方法。你可以提前在网上预订，大部分的代理公司都有网上预订服务，而且网上提供优惠价格，比市价便宜很多。如果不是旺季，也可以到达机场后可以直接在租车的柜台订车。每个代理公司的具体计费方法不同，签订单之前需要仔细进行了解。<br>gaigaiff 在夏威夷开车需注意的是各个stop标志，在有此标志的地方必须停一下，不管有没有人，如果被警察逮到没停，后果不堪设想啊。在夏威夷加油是自助式的，只要和加油站店里的人说“I need gas for my car”然后告知你在第几个车位、买多少、交钱就可以了。
1022900400	4	3	此为推荐景点，可自行选购一日游
1022900400	4	4	推荐餐厅【Bubba Gump Shrimp】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站
1022900400	4	5	同前一天入住酒店
1022900400	5	1	夏威夷—东京
1022900400	5	2	今天全天您可以自由安排活动
1022900400	5	3	今天全天您可以自由安排活动，或选择其他丰富的当地活动。<br>推荐活动：【波利尼西亚文化中心】<br>【套餐简介】：<br>1、接送+演出+自助晚餐：畅游七个村落、独木舟水上舞蹈音乐表演、体验圣殿访客中心之旅、欣赏“HA～生命之歌”、自助餐每日名额有限。<br>自助晚餐菜单：新鲜水果，素菜沙拉（切碎的奶酪，胡萝卜条，橄榄，黄瓜片，小玉米，葵花籽，熏肉，菠萝块），当地特色hukilau沙拉，日本酱汤，甘蓝猪肉卷，炸鸡，红烧鲯鳅鱼，茂宜混合蔬菜，肉汁土豆泥，米饭，菠萝面包，巧克力/椰子蛋糕，百事可乐，咖啡和凉茶（以餐厅实际提供的菜色为准）。<br>2、接送+演出+阿里鲁奥餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、阿里鲁奥自助晚餐 、“HA～生命之歌”中排座位。<br>3、接送+演出+大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、大使牛肋排自助晚餐 、“HA～生命之歌”前排座位、“HA～生命之歌”特别导览。<br>4、接送+演出+鲁奥大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、阿里鲁奥自助晚餐、“HA～生命之歌”特别导览、“HA～生命之歌”前排座位。<br>5、接送+演出+超级大使套餐：畅游七个村落、各村落表演VIP专属座位、专属独木舟村落游、独木舟水上舞蹈音乐表演、VIP专属座位、特制夏威夷贝壳花环、夏威夷花环欢迎式、个人专属导游园区导览、精致餐点、后台参观、“HA～生命之歌” VIP贵宾席、圣殿访客中心之旅、表演节目DVD纪念光盘。<br>注意：<br>1）由于该行程抵达文化村的时间在15：00-15：30左右，且每个村落的表演时间都不一样，所以可能无法带您逛完所有的村落，用餐时间也会根据每天的人数等调整。请您谅解。<br>2）鲁奥大使套餐的用餐时间比其他套餐的用餐时间早30分钟左右，所以参观部落村及观看演出的时间会减少。请您谅解。<br><br>早餐、午餐、晚餐敬请自理。<br><br>
1022900400	5	4	推荐餐厅【California Pizza Kitchen】美国有名披萨连锁店，起源于加利福尼亚的比弗利山庄，已有近30年的历史。饮料可以免费续杯。交通：可乘坐公交2L、22、E路Kalakaua Ave + Opp Seaside Ave站下车即可。
1022900400	5	5	同前一天入住酒店（或可自行选择其他入住酒店）
1022900400	6	1	时差问题今日 抵达东京—东京迪士尼度假区
1022900400	6	2	在酒店享受悠闲的早餐
1022900400	6	3	可自行选购送机服务
1022900400	6	4	搭乘国际航班前往东京
1022900400	6	5	今日住宿因为时差问题是在飞机上度过，享受您的飞行时刻
1022900400	7	1	迪士尼欢乐游
1022900400	7	2	抵达东京后直接前往迪士尼酒店入住<br><br>可由机场直接搭乘利木津巴士前往迪士尼。<br>若抵达时间较晚建议第二天在前往迪士尼乐园。
1021232487	8	5	抵达国内，结束了此次美妙的夏威夷之旅！
1022900400	7	3	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
1022900400	7	4	交通：利木津巴士可直接送至酒店门口。
1022900400	8	1	东京
1022900400	8	2	您可以在酒店餐厅内享用丰富的自助早餐。
1022900400	8	3	交通：从酒店可步行或者搭乘酒店提供的接驳巴士。
1022900400	8	4	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
1022900400	8	5	交通：从迪士尼海洋可步行或者搭乘酒店提供的接驳巴士。
1022900400	9	1	可选购富士山+河口湖一日游
1022900400	9	2	您可以在酒店餐厅内享用丰富的自助早餐。
1022900400	9	3	东京迪士尼园区至浅草寺，换乘方法：<br>1、先乘坐京叶线至东京站；<br>2、换乘银座线·浅草行至浅草站。 
1022900400	9	4	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 <br>s
1022900400	9	5	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
1022900400	9	6	浅草寺搭乘银座线到上野站，车程约5分钟。
1022900400	9	7	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼字号店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种做 法，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。
1022900400	9	8	搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
1022900400	10	1	东京-国内
1022900400	10	2	您可以在酒店餐厅内享用丰富的自助早餐。
1022900400	10	3	新宿西口（平成观光候车室）<br>地址：東京都新宿区西新宿１－２１－１１　山銀ビル（bill)４F <br>集合时间：08:15
1022900400	10	4	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。
1022900400	10	5	搭乘旅游巴士返回东京新宿。
1022900400	10	6	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>交通：搭乘JR山手线至新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
1022900400	10	7	交通：从新宿商圈可步行返回酒店。
1022900400	10	8	东京-国内
1022900400	10	9	您可以在酒店餐厅内享用丰富的自助早餐。
1022900400	10	10	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1022900400	10	11	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1022900400	10	12	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1022900400	10	13	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1022900400	10	14	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1022900400	10	15	乘坐舒适的班机返回国内，结束本次愉快的旅途
1022900400	10	16	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1023219218	1	1	国内出发地_夏威夷
1023219218	2	1	欧胡岛
1023219218	2	2	请至少提前3小时自行前往机场办理登机手续<br> 抵达夏威夷后，前往办理相关入境手续并提取行李
1023219218	2	3	自由规划行程建议您单独预订接送机服务
1023219218	2	4	备注：<br>夏威夷酒店通常在下午15:00PM后办理入住；如您抵达酒店时无法办理入住，请客人把行李寄存在酒店后开启自由度假时光。
1023219218	3	1	欧胡岛
1021232487	2	2	如不需要升级套餐，请在下一步将默认份数更改为0，则您所预定的产品仅为机票+酒店套餐
1018205338	3	1	夏威夷檀香山
1023219218	3	2	自由活动。伴着太平洋微风，暂时忘却各种不如意，拥抱眼前的碧海蓝天，并微笑着前行。<br>【波利尼西亚文化村】<br>波利尼西亚文化中心，将在专业导游的帶領下参观七個不同文化特色的部落，了解波利尼西亚原居民的风土人情。晚間享受丰盛的美食水果自助餐。餐后欣赏由一百多位演員参加的大型夏威夷传统歌舞表演，及活人吞火的惊险火把表演。（感恩节和圣诞节不开放）
1023219218	3	3	推荐餐厅【Nico's Pier 38】<br>地址：1129 N. Nimitz Hwy, Honolulu, HI 96817
1023219218	4	1	夏威夷_家
1023219218	4	2	自由活动。<br>【大岛一日游】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。
1023219218	4	3	推荐餐厅【Waikiki Brewing Company】<br>地址：​​1945 Kalakaua Avenue, Honolulu, HI 96815
1023219218	5	1	抵达
1023219218	5	2	请至少提前3小时自行前往机场办理登机手续
1023219218	5	3	抵达
1023219218	5	4	抵达，结束短暂而又难忘的夏威夷之旅。
1023219218	5	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1979124	1	1	原居地_洛杉矶
1979124	2	1	洛杉矶
1979124	2	2	今日搭乘航班飞往洛杉矶，后送往酒店休息。
1979124	2	3	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	4	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	5	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	6	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	7	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	8	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	9	拉斯夜游35
1979124	2	10	羚羊彩穴+马蹄湾
1979124	2	11	大峡谷国家公园
1979124	2	12	此自费价格表仅供参考，具体售价可能会少许浮动，已当地实际售价为准
1979124	2	13	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	14	此自费价格可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	15	此自费价格可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	16	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	17	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	18	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	19	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	20	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	21	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	22	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	23	西峡谷直升飞机（含峡谷游船）
1979124	2	24	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	2	25	南峡谷直升机
1979124	2	26	此自费价格表可参考，具体售价可能会有少许浮动，以当地的实际售价为准！
1979124	3	1	洛杉矶_拉斯维加斯
1979124	3	2	1. 洛杉矶市区深度一日游；<br />2. 圣地亚哥-海洋世界精华一日游；<br />3. 圣地亚哥一日游：航母 游船 老城风情；<br />4. 棕榈泉名品直销购物中心一日游；<br />5. 加州乐高乐园一日游4/1/2018-8/31/2018出团；<br />6. 太平洋水族馆-赏鲸-爱荷华号战舰一日游；<br />7. 迪斯尼乐园欢乐一日游；<br />8. 好莱坞-环球影城畅怀一日游；<br />9.加州迪士尼冒险乐园一日游；
1979124	3	3	洛杉矶
1979124	4	1	拉斯维加斯自由活动
1979124	4	2	迎着朝阳，乘坐我们的大巴，开始精彩的行程。沿十五号公路北行，穿过圣伯纳丁诺森林，进入莫哈维沙漠。形单影孤的约书亚树一棵棵点缀在一望 无际的戈壁滩上，别有一番情趣。途中短暂停留休息后，于中午抵达拉斯维加斯！
1979124	4	3	若遇到特殊情况比如酒店满房，则更换为同标准酒店。
1979124	4	4	拉斯维加斯
1979124	5	1	拉斯维加斯_夏威夷
1979124	5	2	全天自由活动（无车、餐、导游等服务）。<br />今日您可探亲访友，或酒店内休息，或出门游览拉斯维加斯的有名景点！
1979124	5	3	若遇到特殊情况比如酒店满房，则更换为同标准酒店。
1979124	5	4	拉斯维加斯
1979124	6	1	小环岛
1979124	6	2	提醒您夏威夷酒店入住时间是下午3点钟以后，如您的航班抵达时间过早，您也可以去威基基海滩散步，晒太阳~
1979124	6	3	夏威夷
1979124	7	1	珍珠港_市区游览
1979124	7	2	睡到自然醒，调整时差，畅游威基基海滩。
1979124	7	3	檀香山
1979124	8	1	全天自由活动
1979124	8	2	自由活动，畅游威基基海滩。
1979124	8	3	Waikiki
1979124	9	1	夏威夷_原居地
1979124	9	2	全天自由活动（无车、餐、导游等服务）。<br />今日您可探亲访友，或酒店内休息，或出门游览夏威夷的有名景点！
1979124	9	3	夏威夷_原居地
1979124	9	4	今日搭乘航班返回原居地。
1979124	9	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1021232487	1	1	国内出发地_夏威夷
1021232487	2	3	请至少提前3小时自行前往机场办理登机手续<br/> 抵达夏威夷后，前往办理相关入境手续并提取行李
1021232487	2	4	抵达夏威夷，导游接机后送往当地酒店办理入住。 <br/> 1.国际航班(MU/KE/NH/OZ)早上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机  <br/> <br>2.国际航班(CA/HA)晚上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机 <br/> <br>3.美国本土国内到达的客人,请到行李提取处跟导游汇合。我们导游会穿蓝色Polo体桖举牌接机 <br/> <br>注：接机为当地散拼，可能需要等到同航班其他客人全部出来后才能出发。
1021232487	2	5	备注：<br>夏威夷酒店国际惯例，要下午15:00PM入住，如果酒店不能入住，请客人把行李寄存在酒店，之后自由活动。<br/>
1021232487	3	1	欧胡岛
1021232487	3	2	上午参加：珍珠港+市区游+珠宝博物馆参观。（行程参考时间7:30am-11:30am，以接机导游给到的行程确认单为准）<br>【珍珠港】位于美国夏威夷州欧胡岛上的海港，位于该州首府檀香山西方。东距火奴鲁鲁约10公里。面积89平方公里。港区掩蔽条件好，水域回旋余地大，为世界天然良港。土著夏威夷人称珍珠港为\\
1021232487	3	3	夏威夷当地海岛珠宝展示馆参观
1021232487	3	4	波利尼西亚文化中心
1021232487	3	5	行程游览结束后驱车送往酒店。
1021232487	4	1	欧胡岛
1021232487	4	2	上午恐龙湾浮潜（含浮潜工具，门票自理）下午大环岛北岸精品游。特别包含夏威夷卡胡库风味虾餐（行程参考时间13:00pm-18:00pm，以接机导游给到的行程确认单为准）<br>
1021232487	4	3	【恐龙湾】<br>恐龙湾Hanauma Bay是来夏威夷的游客喜欢去的潜水的地方之一。水浅，浪小，鱼多，风景美丽，那里有各种天然的珊瑚礁石和热带鱼类。恐龙湾是海底死火山，火山口的一面受海浪万年不变的拍击而倒塌，变成象马蹄的形状，所以又被戏称为马蹄湾。恐龙湾是中国人给起的名字，因为从海湾的一头远远望去，恐龙湾就像一头窝在海水中的恐龙。
1021232487	4	4	特色虾餐
1021232487	4	5	<br>游览欧胡岛的北岸， 这个是几乎是来自世界各地游客必去的夏威夷高人气线路，欧胡岛精华丽的海岸线，我们开车穿越帕里森林公路，一路观赏Ko'olau山脉，绿树成荫，然后来到Ko'olau山谷之中的一座悠静古庙—平等院（门票自理）。这座庙宇建于1968年，整座建筑没有一颗钉子，完整呈现了山谷空悠的自然之美，西安事变主角张学良先生和赵四女士就是葬在此处，大家可以到这里瞻仰一下这位改变中国历史的名人。离开Koolau 山脉我们会进入另一个夏威夷的Kualoa 山谷，美国总统奥巴马夫人在APPTEC会议期间就在此处宴请各国第一夫人，当你看到这山谷的时候一定会觉的似曾相识的感觉，侏罗纪公园，风语者，初恋50次和迷失都在那里拍摄的，这里是好莱坞导演的挚爱之地。之后前往 下 一站 MACADAMIANUT FARMOUTLET（夏威夷果农场），这 里你可品尝各种夏威夷土特产：火山 豆，咖啡等了解夏威 夷农产品 的种植情 况 ，增长相关 知识 。然后驾车前往KAHUKU ，在那里你可以品尝只有夏威夷才能吃到的KAHUKU甜虾之后前往北海岸北处的落日海滩，那是欧胡岛受欢迎的冲浪海滩冲浪者的天堂，是现代冲浪运动的起源地，每到冬季世界各地冲浪好手到此朝圣，并在此地一较高下，也就是世界冲浪锦标赛的官方指定比赛地点。下一站途径是总统奥巴玛喜欢的哈雷伊瓦小镇，每年回来度假，总统一家 都会 光顾这 里，展示第 一家 庭 的亲民，奥巴马女儿 喜欢那里的彩虹冰（途径）。后我们观光车会停在都乐菠萝园农场让 游客们下车拍照 ，沿途 一片农家田园风情。
1021232487	4	6	行程结束后返回酒店，晚餐自理
1021232487	5	1	欧胡岛
1021232487	5	2	当天行程为二选一 古兰尼牧场体验之旅 或者 海洋公园（海豚邂逅）
1021232487	5	3	今日游玩项目可自选（二选一） <br/> <br>古兰尼牧场：【自然与探险之旅】 <br/> <br>古兰尼牧场是每一位到夏威夷的游客都不容错过的景点之一。这里山峦叠嶂，树木葱郁，还有波光粼粼的大海和细白沙滩，清新优美的自然风光使其成为《侏罗纪公园》、《迷失》等诸多大片的拍摄地。再加上骑马、吉普车丛林越野、独木舟、双体船出海等花样繁多的娱乐项目，对于童心未泯的朋友们来说，简直就是探险大自然的不二去处。 <br/> <br>最近上演的《侏罗纪世界2》故事的中的努布拉岛，也是在夏威夷古兰尼牧场取景拍摄的。作为一个真正的侏罗纪系列影迷，如果想要去电影中的努布拉岛朝圣，想要化身电影的男主女主，亲身经历一下这个史前动物乐园，就不能错过古兰尼牧场这个好莱坞电影御用拍摄地。 <br/> <br>午餐：沙拉，韩式泡菜，鸡肉BBQ，牛肉BBQ，甜品，饭，饮料等自助餐，请以实际安排为准。 <br/> <br>【体验套餐】：安排【山谷体验之旅：游览好莱坞拍摄地】 【深山体验之旅：吉普车丛林越野】   【古代生态植物园】   午餐（如果有婴儿不能参加【深山体验之旅：吉普车丛林越野】项目公司会尽量安排【海洋体验之旅：迎风追浪】代替，如当天关闭则视客人自动放弃该行程） <br/> <br>1、【山谷体验之旅：游览好莱坞拍摄地】<br>如果你是好莱坞美剧控，牧场北半部的卡阿瓦山谷一定会令你惊叹不已。这里一直是无数热门电视节目和好莱坞电影的取景地，神奇的抓印造型山脉和倒塌的大枯树干让人仿佛置身于《侏罗纪公园》紧张刺激的真实场景中，你还有机会与微缩版复活节岛摩艾石像合影，途经《迷失》中Hurley打高尔夫球的球场，看一看《哥斯拉》留下的怪兽大脚印。 <br/> <br>2、【深山体验之旅：吉普车丛林越野】<br>坐上老式的军用吉普车，沿着蜿蜒的小路和起伏的山丘，来场热带雨林穿越吧！约90分钟的车程中，充满原始热带风情的哈基普雾（Hakipuu）山谷尽收眼底。游览过程中，你还将有机会短程步行到高台，俯瞰瓦胡岛东部海岸线和古代夏威夷鱼塘的美丽风光。 <br/> <br>3、【海洋体验之旅：迎风追浪】<br>踏上双体船，游览卡内奥赫海湾（Kaneohe Bay），你将离开古兰尼主园区，从Moli’i码头登上49人的双体船驶入Kaneohe海湾。在海面上您可以将整座古兰尼山尽收眼底，同时也有机会近距离接触Mokoli’i岛（又名“草帽岛”）。如果好的话，甚至可以从船上看到鲸鱼和海龟！一定要带上您的相机哦！ <br/> <br>备注：海洋巡游活动周日和美国公众假期不开放，9岁或以下儿童必须有监护人陪同参加。 <br/> <br>4、【3小时神秘岛活动】<br>神秘岛海滩是一个僻静的私人海滩，是一个放松自我，舒缓压力的好去处，是您夏威夷之行的选项之一。我们为您提供了各式各样的设备与器具，您可以放松的与大海来一次亲密接触！<br>您只需带上泳衣，浴巾，防晒霜以及相机，我们为您准备了丰富的海上活动！神秘岛上为您免费提供了香蕉船，皮划艇，独木舟，冲浪板，沙滩排球，乒乓球，羽毛球，凉席，吊床以及更多好玩的水上活动设施。或者您可以伴着海风在吊床上休息，或乘坐玻璃底船出海寻找海龟。神秘岛上设有更衣室和淋浴，建议您携带一件用于更换的衣服和毛巾。 <br/> <br>备注:玻璃底船周日不开放。 <br/> <br>5、【古代生态植物园】<br>古代生态植物园之旅给您一个机会深入了解古代夏威夷的文化和历史。您将会经过古兰尼的Moli’i热带花园。热带花园中不仅有夏威夷本土的植物，也有世界各地的植物花卉。您将会学习第一批夏威夷人是怎样将各种植物带上岛并成功种植。参观完热带花园后，您将有机会亲自品尝植物园中的水果。 <br/> <br>备注：9岁或以下儿童必须有监护人陪同参加。 <br/> <br>夏威夷海洋公园海豚邂逅 <br/> <br>凡是预定邂逅海豚节目，凭电子确认函入园即可特别获得价值10美金的Beachboy Lanai Food court 餐券。<br>游客可站在水深齐腰的平台上观察海豚表演。海豚会与游客玩耍，亲吻游客，甚至和游客一起“舞蹈”！如果天气允许，您还可以与海豚拍照留念。 <br/> <br>海豚邂逅入场时间：10:15 am/11:45 am/13:00 pm/14:30 pm（水中时间：30分钟）
1021232487	5	4	推荐餐厅【Wolfgang's Steakhouse】<br>由Wolfgang Zwiener一手创办的牛排餐厅，他曾于名震纽约餐饮界的牛排馆Peter Luger Steakhouse工作40余年，对厨艺上从无间断的精进，让沃尔夫冈牛排馆自成立以来形成独树一帜的牛排文化，无与伦比的美味征服了无数美食爱好者的味蕾，成为美国备受推崇的牛排馆之一。
1021232487	6	1	欧胡岛
1021232487	6	2	推荐活动：<br>【大岛一日游】<br>特色景点：<br>【夏威夷大岛：在热带滑雪】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br>【夏威夷火山国家公园：看火山熔岩】<br>来到大岛，夏威夷火山国家公园是必游景点。这里坐落着两座活火山茂纳洛亚火山（Mauna Loa）和基拉韦厄（Kilauea），毁灭与新生在此并存。站在巨大的火山口旁，看通红炽热的岩浆在火山湖中流淌，堪称大自然奇观。穿过历史悠久的熔岩通道，尽头又是一片葱郁繁茂的热带雨林，颇有柳暗花明又一村之感。<br>【希洛海湾黑沙滩：邂逅玳瑁和绿海龟】<br>大多数人对于夏威夷的印象是碧海白沙，而大岛由于火山活动频繁，造就了这里奇特的黑沙滩。光脚漫步在纯黑色的沙地上，触感竟然分外细腻柔软。入眼所及，清冽的海水和锃亮黝黑的岩石在阳光的照耀下形成鲜明有趣的对比，由于黑色的沙子能更好的吸收太阳光，趴在沙滩上进行日光浴也是十分悠闲愉快的享受。当地的两种珍惜动物——玳瑁和绿海龟也会时常出没此地晒太阳，快来与它们邂逅吧。<br>【彩虹瀑布：对彩虹许愿】<br>彩虹瀑布由左、右两道水流交汇而成，犹如一匹白练般从岩石顶端倾泻而下，落入水潭中激起层层水雾。再加上四周青翠茂盛的热带植物映衬，景色怡人。等到天气晴好时，瀑布的水雾在阳光的折射下形成了一道灿烂的彩虹天桥，横架在水潭上方，又给这幅山水画卷添上了绚丽多彩的一笔。
1021232487	6	3	推荐餐厅【Roy's Waikiki】<br>Roy's 餐厅是夏威夷的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。建议提前1-2天订位。
1021232487	7	1	欧胡岛_国内出发地
1021232487	7	2	推荐活动【亚特兰蒂斯潜水艇】深入80英尺的海底世界，探秘古老的沉船遗迹，欣赏各种海底生物。不用“湿身”，就能畅游海底王国，不会游泳的朋友也无需担心
1021232487	7	3	推荐【夏威夷幻像魔术草裙舞晚宴】<br>
1021232487	8	1	国内
1021232487	8	2	提前3小时送机前往机场，后搭乘航班返回国内。
1021232487	8	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
5515779	1	1	国内-洛杉矶
5515779	2	1	洛杉矶
5515779	2	2	搭乘航班从国内飞往洛杉矶。
5515779	2	3	【如何搭乘免费班车】<br>接驳车位于LAX机场行李盘外，显示为“Hotel & Courtesy Shuttle”的红色显示屏下。在车身或车头印有各家酒店名称。单程行驶时间为10-15分钟。建议每件行李支付1美元小费。
5515779	3	1	洛杉矶
5515779	4	1	洛杉矶-拉斯维加斯
5515779	5	1	拉斯维加斯
5515779	5	2	特别优惠：399元即可换购位于MGM酒店内的大型歌舞表演KA秀。
5515779	6	1	拉斯维加斯-夏威夷
5515779	6	2	建议前往世界七大奇景之一的科罗拉多大峡谷一日游。您可在成功预订后添加我们的一日游产品。
5515779	7	1	夏威夷
5515779	7	2	请自行预订拉斯维加斯飞往夏威夷航班。（此产品中不含美国内陆机票）
5515779	7	3	Tropicana距离拉斯维加斯机场约2.5公里，搭乘出租车是性价比高的方式，行驶时间大约10分钟，价格20美金左右。<br>抵达夏威夷后导游接机送往酒店。
5515779	8	1	夏威夷
5515779	8	2	上午前往珍珠港参观第二次大战日本偷袭原址。观看珍贵的历史纪录片，并乘船前往参观被日军炸沉的亚历山大号战舰残骸。随后送往Waikele Premium自由购物。（此日行程可能根据实际情况与下面一日对换）
5515779	9	1	夏威夷-国内
5515779	9	2	上午小环岛半日游，中午赠送夏威夷特色牛排餐，下午Ala Moana自由购物。<br>
5515779	10	1	国内
5515779	10	2	上午送往机场，搭乘航班返回国内。
5515779	10	3	国内
5515779	10	4	安全抵达国内<br>
5515779	10	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1020460554	1	1	出发地—夏威夷
1020460554	2	1	夏威夷檀香山
1020460554	2	2	办理登机:请自行直接在出发地机场国际出发大厅办理登机<br><br>航班信息:由出发前往夏威夷（具体航班信息请在预订下一步中查看）
1020460554	2	3	如何前往酒店？<br>1、预订携程拼车接送机服务（请在下一步点击预订）<br>2、自驾/租车--建议前往携程用车部门预定，如没有多年自驾经验，不建议租车自驾<br>3、机场打车请提前与司机确认好价格
1020460554	2	4	夏威夷酒店通常在下午三点开始办理酒店入住
1020460554	2	5	这段时间您也可以去威基基海滩散散步，或者游游泳，或者只是躺在沙滩上晒晒太阳，打个小盹，或者租冲浪板去随波逐浪。<br> <br>晚餐：敬请自理<br> <br>晚上您可以去享用美食，在熙熙攘攘的Kalakaua大街上有各种餐厅和酒吧，并可以欣赏街头艺术，使您流连忘返。 
1020460554	3	1	夏威夷檀香山
1020460554	3	2	推荐：珍珠港半日游<br>7:20上门接：（周二、四、六、日）夏威夷威基基Waikiki区域的酒店（除Kahala酒店外）门口等候（具体地点以确认单为准）（不在waikiki区域的酒店请客人自行前往waikiki区域集合）<br>7:30交通：乘巴士前往珍珠港<br>8:00游玩景点： 珍珠港、 卡美哈美哈国王铜像、 夏威夷州议会大厦、 伊奥拉尼王宫12:30就地散团 ：返回出发地自行散团，愉快地结束行程<br>*行程时间为游玩地当地时间，以上行程可能会因天气、路况等原因做相应调整，敬请谅解。<br><br>
1020460554	3	3	Poke这道菜是用新鲜的金枪鱼和鳄梨做成的，是典型的夏威夷特色食品。把金枪鱼用酱油、芥末和料酒、麻油腌渍30分钟，再把鳄梨切块与金枪鱼块搅拌在一起，加上海苔便做成了。
1020460554	4	1	夏威夷檀香山
1020460554	4	2	推荐：经典小环岛半日游<br>7:30上门接：（每周一三五）夏威夷威基基Waikiki区域的酒店门口等候<br>8:00游玩景点： 威基基海滩、 钻石头山<br>8:15游玩景点： 卡哈拉度假区、 喷泉洞<br>9:15游玩景点： 恐龙湾<br>10:00游玩景点： 白沙滩（车览）<br>10:05游玩景点： 夏威夷土著保护区（车览）<br>10:10游玩景点： 大风口<br>10:35返程散团 ：乘巴士返回威基基区域酒店散团<br>途径PUPU OUTLETS,您可随意选购水果，零食，泡面等价廉物美的必需品<br>11:20愉快地结束当天的行程！<br>*行程时间为游玩地当地时间，以上行程可能会因天气、路况等原因做相应调整，敬请谅解。
1020460554	4	3	推荐餐厅：Bubba Gump Shrimp<br>餐厅在欧胡岛上，在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。这家餐馆的受欢迎程度，只要看看饭点时在门口聚集等候的人群就知道了。<br>交通<br>可搭乘公交车至Ala Moana Bl + Ala Moana Center站。
1020460554	5	1	夏威夷檀香山
1020460554	5	2	推荐：波利尼西亚文化中心一日游<br>13:00上门接：威基基区域酒店门口<br>接送车将于13:30左右在威基基区域酒店门口停留，请提前5-10分钟抵达。营业时间：每周二、四、六13：00-21：00，感恩节和圣诞节关门。<br>13:30交通：乘车前往文化村<br>15:00游玩景点： 波利尼西亚文化中心<br>18:00晚餐：非自理<br>19:30游玩项目：观看演出<br>21:00返程送回 ：有车送回出发酒店<br>22:00愉快地结束当天的行程！<br>*行程时间为游玩地当地时间，以上行程可能会因天气、路况等原因做相应调整，敬请谅解。
1020460554	5	3	畅游六个夏威夷原著村落，体验和原住民一起击鼓、跳舞的乐趣
1020460554	5	4	推荐餐厅：Hard Rock Cafe <br>Hard Rock是世界知名的摇滚主题美式餐厅，一楼是卖周边产品的，二楼才是餐厅。你可以选择香醇的烈酒、冰凉的啤酒、风味独特的鸡尾酒或者咖啡等饮品，此外这里也提供西餐，食物美味，分量很多。到了晚上，还有现场乐队表演，为食客们助兴。<br>
1020460554	6	1	夏威夷-出发地
1020460554	6	2	推荐：古兰尼牧场一日游<br>7:00集合：<br>Ala Moana Hotel(侧门 MAHUKONA STREET）<br>INTERNATIONAL MARKET PLACE (KONA COFFEE SHOP ）<br>WAIKIKI BEACH MARRIOTT HOTEL PAOAKALANI STREET门外<br>HILTON HAWAIIAN VILLAGE GRAND ISLANDER TOWER LOWER<br>7:15集合：<br>SHERATON WAIKIKI HOTEL<br>PRINCE WAIKIKI HOTEL<br>7:25交通：乘车前往夏威夷古兰尼Kualoa牧场<br>8:10游玩项目：所选套餐活动项目<br>14:30返程送回 ：有车送回出发点<br>15:20愉快地结束当天的行程！
1020460554	6	3	打卡《侏罗纪世界》等众多经典电视电影取景地，探索真实拍摄场景；坐上美式吉普车，欣赏原始热带雨林风光，全程轻松舒适
1020460554	6	4	推荐餐厅：Wolfgang's Steakhouse <br>沃尔夫冈牛排馆是由Wolfgang Zwiener一手创办的牛排餐厅，他曾于名震纽约餐饮界的牛排馆Peter Luger Steakhouse工作40余年，对厨艺上从无间断的精进及对完 美矢志不渝的追求，让沃尔夫冈牛排馆自成立以来形成独树一帜的牛排文化，无与伦比的美味征服了无数美食爱好者的味蕾，成为美国备受推崇的牛排馆之一。<br>交通<br>可乘坐公交2L、22、E路至Kalakaua Ave + Opp Seaside Ave站下车即可。
1020460554	7	1	抵达
1020460554	7	2	根据航班时间提前退房。如您预订了我司提供的送机服务，司机会出现在酒店，接您去机场办理手续。
1020460554	7	3	乘机返回出发地。（具体航班信息请在预订下一步中查看） 
1020460554	7	4	抵达
1020460554	7	5	返回温馨的家，结束了此次美妙的夏威夷之旅！ 
1020460554	7	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1018632811	1	1	出发地—夏威夷
1018632811	2	1	北岸大环岛，大排档虾餐
1018632811	2	2	办理登机:请自行直接在出发地机场国际出发大厅办理登机
1018632811	2	3	抵达美国，办理相关入境手续，导游接机。<br>到达的客人，请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机
1018632811	2	4	赠市区观光游览，【CA/HA】等晚上到达的航班直接送往酒店，不参加市区观光活动
1018632811	2	5	自行选择入住酒店（温馨提醒：请选择威基基区域酒店）<br>夏威夷酒店通常在下午三点开始办理酒店入住手续，这段时间您也可以去威基基海滩散散步，或者游游泳，或者只是躺在沙滩上晒晒太阳，打个小盹，或者租冲浪板去随波逐浪。
1018632811	3	1	珍珠港知历史，Waikele Premium Outlets剁手买
1018632811	3	2	上午参加大环岛行程（含大排档虾餐），请提前前往导游约定的集合点等待。<br>欧胡岛精华的北海岸，座落于Ko’olau山谷之中的一座悠静古庙—平等院。接着参观张学良先生和赵四女士的墓地，张学良是西安事变的主角。<br>下一站是MACADAMIA NUT FARM OUTLET，这里你可品尝各种夏威夷土特产：火山豆，咖啡等。<br>然后驾车前往KAHUKU，在那里导游会带您品尝只有夏威夷才能吃到的KAHUKU大排档虾餐。<br>之后前往北海岸北处的落日海滩，那是欧胡岛非常受欢迎的海滩，也是冲浪者的天堂。<br>之后停留都乐菠萝园，沿途一片农家田园风情， 客人可以自费坐小火车或者品尝那里菠萝冰淇淋。
1018632811	3	3	网红大排档虾餐。可自选辣与不辣两种口味。
1018632811	3	4	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可
1018632811	4	1	小环岛，Ala Moana购物中心
1018632811	4	2	今日参加珍珠港+Waikele Premium Outlets一日游，请提前前往导游约定的集合点等待。<br>夏威夷标志性景点，是您不容错过的景点，亲临珍珠港，参观被日军炸毁的亚利桑那战舰残骸，缅怀阵亡将士。之后前往Waikele Premium Outlets畅爽购物
1018632811	4	3	推荐餐厅【Bubba Gump Shrimp】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站
1018632811	5	1	夏威夷檀香山
1018632811	5	2	今日参加小环岛+Ala Moana购物中心一日游。参观知名的景点钻石头山、恐龙湾、喷水口、大风口等！<br>请提前前往导游约定的集合点等待。
1018632811	5	3	特色午餐
1018632811	6	1	 夏威夷檀香山
1018632811	6	2	推荐项目：谷兰尼牧场( 半日游）、谷兰尼牧场( 一日游)（详见>>费用>>推荐活动参考）<br><br>打卡《侏罗纪世界》等众多经典电视电影取景地，探索真实拍摄场景<br>坐上美式吉普车，欣赏原始热带雨林风光，全程轻松舒适<br>双体船出海巡游，划皮艇、独木舟、沙滩排球等精彩活动等你来玩
1018632811	6	3	推荐餐厅【Roy's Waikiki】Roy's 餐厅是夏威夷有名的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。丰盛大餐配上优质的服务，不容错过，建议提前1-2天订位。交通<br>：可乘坐公交8、19、20、23、42至Kalia Rd + Saratoga Rd站下车，向东南方步行10分钟即可
1018632811	7	1	 夏威夷-出发地 
1018632811	7	2	推荐项目：波利尼西亚文化中心<br>观赏特色舞蹈及技艺，体验各族的文化、历史及热情。
1018632811	7	3	推荐餐厅【馥苑海鲜餐厅】餐厅距离威基基海滩不远，餐厅很火爆，尤其受国人欢迎，饭点经常需要等位。味道是熟悉的中餐味道，服务也很不错，招牌的龙虾新鲜美味、做 法选择很多。<br><br>
1018632811	8	1	 出发地
1018632811	8	2	体验过夏威夷的热情。今天前往机场，乘机返回出发地。（具体航班信息请在预订下一步中查看）
1018632811	8	3	早餐后，由导游安排送机。
1018632811	8	4	 出发地
1018632811	8	5	抵达目的地，结束了此次美妙的夏威夷之旅！
1018632811	8	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1018205338	1	1	出发地—夏威夷
1018205338	2	1	夏威夷檀香山
1018205338	2	2	办理登机:请自行直接在出发地机场国际出发大厅办理登机<br><br>航班信息:由出发前往夏威夷（具体航班信息请在预订下一步中查看）
1018205338	2	3	抵达美国，办理相关入境手续，导游接机。<br>温馨提示：接送机服务及以下行程仅推荐，如不需要请在下一步默认行程中，将份数更改为0，则您所预订的产品仅含机票+酒店。<br>
1018205338	2	4	夏威夷酒店通常在下午三点开始办理酒店入住手续，这段时间您也可以去威基基海滩散散步，或者游游泳，或者只是躺在沙滩上晒晒太阳，打个小盹，或者租冲浪板去随波逐浪。<br> 晚餐：敬请自理<br> 晚上您可以去享用美食，在熙熙攘攘的Kalakaua大街上有各种餐厅和酒吧，并可以欣赏街头艺术，使您流连忘返。 
1018205338	3	2	（今日推荐行程为【夏威夷珍珠港半日游】，客人可根据喜好选择日期） <br>温馨提醒：选择此行程日期请勿与航班日期重叠。
1018205338	3	3	推荐餐厅【Bubba Gump Shrimp (Oahu)】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站。
1018205338	4	1	夏威夷檀香山
1018205338	4	2	（今日推荐行程为【夏威夷小环岛半日游】，客人可根据喜好选择日期） <br>温馨提醒：选择此行程日期请勿与航班日期重叠。
1018205338	4	3	您可选择漫步于喧闹的街市，领略当地的街头文化；或者和海风、沙滩、阳光来上一次亲密接触，让自己的身体学着放松和享受！<br>晚餐：敬请自理
1018205338	4	4	推荐餐厅【Eggs N Things】夏威夷人气旺的饭店之一，新鲜出炉的烤饼以及这里的招牌菜——蛋包饭都是必点的食物。交通：乘坐公交车8、19、20路至Saratoga Rd + Kalakaua Ave站下车。
1018205338	5	1	夏威夷檀香山
1018205338	5	2	推荐自选活动：<br>【大岛一日游】<br>特色景点：<br>【夏威夷大岛：在热带滑雪】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br>【夏威夷火山国家公园：看火山熔岩】<br>来到大岛，夏威夷火山国家公园是必游景点。这里坐落着两座活火山茂纳洛亚火山（Mauna Loa）和基拉韦厄（Kilauea），毁灭与新生在此并存。站在巨大的火山口旁，看通红炽热的岩浆在火山湖中流淌，堪称大自然奇观。穿过历史悠久的熔岩通道，尽头又是一片葱郁繁茂的热带雨林，颇有柳暗花明又一村之感。<br>【希洛海湾黑沙滩：邂逅玳瑁和绿海龟】<br>大多数人对于夏威夷的印象是碧海白沙，而大岛由于火山活动频繁，造就了这里奇特的黑沙滩。光脚漫步在纯黑色的沙地上，触感竟然分外细腻柔软。入眼所及，清冽的海水和锃亮黝黑的岩石在阳光的照耀下形成鲜明有趣的对比，由于黑色的沙子能更好的吸收太阳光，趴在沙滩上进行日光浴也是十分悠闲愉快的享受。当地的两种珍惜动物——玳瑁和绿海龟也会时常出没此地晒太阳，快来与它们邂逅吧。<br>【彩虹瀑布：对彩虹许愿】<br>彩虹瀑布由左、右两道水流交汇而成，犹如一匹白练般从岩石顶端倾泻而下，落入水潭中激起层层水雾。再加上四周青翠茂盛的热带植物映衬，景色怡人。等到天气晴好时，瀑布的水雾在阳光的折射下形成了一道灿烂的彩虹天桥，横架在水潭上方，又给这幅山水画卷添上了绚丽多彩的一笔。
1018205338	5	3	推荐自选活动：<br>【波利尼西亚文化中心】<br>【套餐简介】：<br>1、接送+演出+自助晚餐：畅游七个村落、独木舟水上舞蹈音乐表演、体验圣殿访客中心之旅、欣赏“HA～生命之歌”、自助餐每日名额有限。<br>自助晚餐菜单：新鲜水果，素菜沙拉（切碎的奶酪，胡萝卜条，橄榄，黄瓜片，小玉米，葵花籽，熏肉，菠萝块），当地特色hukilau沙拉，日本酱汤，甘蓝猪肉卷，炸鸡，红烧鲯鳅鱼，茂宜混合蔬菜，肉汁土豆泥，米饭，菠萝面包，巧克力/椰子蛋糕，百事可乐，咖啡和凉茶（以餐厅实际提供的菜色为准）。<br>2、接送+演出+阿里鲁奥餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、阿里鲁奥自助晚餐 、“HA～生命之歌”中排座位。<br>3、接送+演出+大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、大使牛肋排自助晚餐  、“HA～生命之歌”前排座位、“HA～生命之歌”特别导览。<br>4、接送+演出+鲁奥大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、阿里鲁奥自助晚餐、“HA～生命之歌”特别导览、“HA～生命之歌”前排座位。<br>5、接送+演出+超级大使套餐：畅游七个村落、各村落表演VIP专属座位、专属独木舟村落游、独木舟水上舞蹈音乐表演、VIP专属座位、特制夏威夷贝壳花环、夏威夷花环欢迎式、个人专属导游园区导览、精致餐点、后台参观、“HA～生命之歌” VIP贵宾席、圣殿访客中心之旅、表演节目DVD纪念光盘。<br>注意：<br>1）由于该行程抵达文化村的时间在15：00-15：30左右，且每个村落的表演时间都不一样，所以可能无法带您逛完所有的村落，用餐时间也会根据每天的人数等调整。请您谅解。<br>2）鲁奥大使套餐的用餐时间比其他套餐的用餐时间早30分钟左右，所以参观部落村及观看演出的时间会减少。请您谅解。
1018205338	5	4	今天全天您可以自由安排活动
1018205338	5	5	三餐敬请自理
1018205338	6	1	夏威夷-出发地
1018205338	6	2	推荐自选项目<br>【恐龙湾浮潜】<br>恐龙湾Hanauma Bay是来夏威夷的游客喜欢去的潜水的地方之一。水浅，浪小，鱼多，风景美丽，那里有各种天然的珊瑚礁石和热带鱼类。恐龙湾是海底死火山，火山口的一面受海浪万年不变的拍击而倒塌，变成象马蹄的形状，所以又被戏称为马蹄湾。恐龙湾是中国人给起的名字，因为从海湾的一头远远望去，恐龙湾就像一头窝在海水中的恐龙。<br>详细行程：<br>07：00-08：00 夏威夷威基基区域酒店拼车接送服务。<br>08：00-11：00 到达恐龙湾后，客人自行下车购买门票。但在游玩前需看一部关于恐龙湾形成与保护的纪录片，因为恐龙湾是国家自然保护区。<br>11：00-11：30 离开恐龙湾（恐龙湾有严格的时间规定，请客人按照司机所要求的时间准时上车，超时无法等待，需要客人自费解决交通问题，请谅解！）。                                                                                                                                           <br>11：30-12：15 抵达威基基区域的酒店。
1018205338	6	3	推荐自选项目：<br>【古兰尼牧场】<br>【90分钟活动自选】<br>1、山谷体验之旅：游览令人叹为观止的卡阿瓦山谷ka'a'awa，体验户外的牧场，农田，观好莱坞大片外景拍摄地如：侏罗纪公园Jurassic Park，迷失Lost，哥斯拉Godzilla等。<br>2、深山体验之旅：一起探索古兰尼丰富的历史和传统，乘坐六轮瑞士军用吉普车去探索原始的哈基普雾山谷Hakipu'u，沿着丛林小道通过河床和陡峭的山丘，探险热带丛林。<br>3、海洋体验之旅：乘坐巴士参观种植了各种不同的热带水果的茉莉依花园，随后游览者瓦胡岛上保存得完好的古代夏威夷鱼塘，享受美丽和宁静的环境，再从神秘岛出发乘坐双体船游览卡内奥赫海湾Kaneohe Bay，欣赏背面的怡人景色。双体船游览活动周日和美国公众假期不开放。<br>【3小时神秘岛活动】<br>神秘岛海滩是一个僻静的私人海滩，是一个放松自我，舒缓压力的好去处。提供不同的海上娱乐设施如划皮艇，划独木舟，以及立浆冲浪等，还提供不同球类活动如沙滩排球，羽毛球，乒乓球等。
1018205338	6	4	今天全天您可以自由安排活动<br>
1018205338	6	5	推荐餐厅【Atlantis Seafood and Steak】美式海鲜牛排店，位于国王大道上。餐厅内的招牌菜是牛排和龙虾意面，牛排肉嫩多汁，意面非常鲜美，是用新鲜龙虾肉烹制而成，且量较大。交通：可乘坐交通2L、22、E路至Kalakaua Ave + Opp Seaside Ave站下车即可。
1018205338	7	1	上海
1018205338	7	2	体验过夏威夷的热情。今天前往机场，乘机返回出发地。（具体航班信息请在预订下一步中查看） 
1018205338	7	3	由导游安排送机。 
1018205338	7	4	上海
1018205338	7	5	抵达上海，结束了此次美妙的夏威夷之旅！ 
1018205338	7	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1017617144	1	1	国内出发地_夏威夷
1017617144	2	1	欧胡岛
1017617144	2	2	如不需要升级套餐，请在下一步将默认份数更改为0，则您所预定的产品仅为机票+酒店套餐
1017617144	2	3	请至少提前3小时自行前往机场办理登机手续<br/> 抵达夏威夷后，前往办理相关入境手续并提取行李
1017617144	2	4	抵达夏威夷，导游接机后送往当地酒店办理入住。 <br/> 1.国际航班(MU/KE/NH/OZ)早上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机  <br/> <br>2.国际航班(CA/HA)晚上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机 <br/> <br>3.美国本土国内到达的客人,请到行李提取处跟导游汇合。我们导游会穿蓝色Polo体桖举牌接机 <br/> <br>注：接机为当地散拼，可能需要等到同航班其他客人全部出来后才能出发。
1017617144	2	5	备注：<br>夏威夷酒店国际惯例，要下午15:00PM入住，如果酒店不能入住，请客人把行李寄存在酒店，之后自由活动。<br/>
1017617144	3	1	欧胡岛
1017617144	3	2	上午参加：珍珠港+市区游+珠宝博物馆参观。（行程参考时间7:30am-11:30am，以接机导游给到的行程确认单为准）<br>【珍珠港】位于美国夏威夷州欧胡岛上的海港，位于该州首府檀香山西方。东距火奴鲁鲁约10公里。面积89平方公里。港区掩蔽条件好，水域回旋余地大，为世界天然良港。土著夏威夷人称珍珠港为\\
1017617144	3	3	夏威夷当地海岛珠宝展示馆参观
1017617144	3	4	波利尼西亚文化中心
1017617144	3	5	行程游览结束后驱车送往酒店。
1017617144	4	1	欧胡岛
1017617144	4	2	上午恐龙湾浮潜（含浮潜工具，门票自理）下午大环岛北岸精品游。特别包含夏威夷卡胡库风味虾餐（行程参考时间13:00pm-18:00pm，以接机导游给到的行程确认单为准）<br>
1017617144	4	3	【恐龙湾】<br>恐龙湾Hanauma Bay是来夏威夷的游客喜欢去的潜水的地方之一。水浅，浪小，鱼多，风景美丽，那里有各种天然的珊瑚礁石和热带鱼类。恐龙湾是海底死火山，火山口的一面受海浪万年不变的拍击而倒塌，变成象马蹄的形状，所以又被戏称为马蹄湾。恐龙湾是中国人给起的名字，因为从海湾的一头远远望去，恐龙湾就像一头窝在海水中的恐龙。
1017617144	4	4	特色虾餐
1017617144	4	5	<br>游览欧胡岛的北岸， 这个是几乎是来自世界各地游客必去的夏威夷高人气线路，欧胡岛精华丽的海岸线，我们开车穿越帕里森林公路，一路观赏Ko'olau山脉，绿树成荫，然后来到Ko'olau山谷之中的一座悠静古庙—平等院（门票自理）。这座庙宇建于1968年，整座建筑没有一颗钉子，完整呈现了山谷空悠的自然之美，西安事变主角张学良先生和赵四女士就是葬在此处，大家可以到这里瞻仰一下这位改变中国历史的名人。离开Koolau 山脉我们会进入另一个夏威夷的Kualoa 山谷，美国总统奥巴马夫人在APPTEC会议期间就在此处宴请各国第一夫人，当你看到这山谷的时候一定会觉的似曾相识的感觉，侏罗纪公园，风语者，初恋50次和迷失都在那里拍摄的，这里是好莱坞导演的挚爱之地。之后前往 下 一站 MACADAMIANUT FARMOUTLET（夏威夷果农场），这 里你可品尝各种夏威夷土特产：火山 豆，咖啡等了解夏威 夷农产品 的种植情 况 ，增长相关 知识 。然后驾车前往KAHUKU ，在那里你可以品尝只有夏威夷才能吃到的KAHUKU甜虾之后前往北海岸北处的落日海滩，那是欧胡岛受欢迎的冲浪海滩冲浪者的天堂，是现代冲浪运动的起源地，每到冬季世界各地冲浪好手到此朝圣，并在此地一较高下，也就是世界冲浪锦标赛的官方指定比赛地点。下一站途径是总统奥巴玛喜欢的哈雷伊瓦小镇，每年回来度假，总统一家 都会 光顾这 里，展示第 一家 庭 的亲民，奥巴马女儿 喜欢那里的彩虹冰（途径）。后我们观光车会停在都乐菠萝园农场让 游客们下车拍照 ，沿途 一片农家田园风情。
1017617144	4	6	行程结束后返回酒店，晚餐自理
1017617144	5	1	欧胡岛
1017617144	5	2	当天行程为二选一 古兰尼牧场体验之旅 或者 海洋公园（海豚邂逅）
1017617144	5	3	今日游玩项目可自选（二选一） <br/> <br>古兰尼牧场：【自然与探险之旅】 <br/> <br>古兰尼牧场是每一位到夏威夷的游客都不容错过的景点之一。这里山峦叠嶂，树木葱郁，还有波光粼粼的大海和细白沙滩，清新优美的自然风光使其成为《侏罗纪公园》、《迷失》等诸多大片的拍摄地。再加上骑马、吉普车丛林越野、独木舟、双体船出海等花样繁多的娱乐项目，对于童心未泯的朋友们来说，简直就是探险大自然的不二去处。 <br/> <br>最近上演的《侏罗纪世界2》故事的中的努布拉岛，也是在夏威夷古兰尼牧场取景拍摄的。作为一个真正的侏罗纪系列影迷，如果想要去电影中的努布拉岛朝圣，想要化身电影的男主女主，亲身经历一下这个史前动物乐园，就不能错过古兰尼牧场这个好莱坞电影御用拍摄地。 <br/> <br>午餐：沙拉，韩式泡菜，鸡肉BBQ，牛肉BBQ，甜品，饭，饮料等自助餐，请以实际安排为准。 <br/> <br>【体验套餐】：安排【山谷体验之旅：游览好莱坞拍摄地】 【深山体验之旅：吉普车丛林越野】   【古代生态植物园】   午餐（如果有婴儿不能参加【深山体验之旅：吉普车丛林越野】项目公司会尽量安排【海洋体验之旅：迎风追浪】代替，如当天关闭则视客人自动放弃该行程） <br/> <br>1、【山谷体验之旅：游览好莱坞拍摄地】<br>如果你是好莱坞美剧控，牧场北半部的卡阿瓦山谷一定会令你惊叹不已。这里一直是无数热门电视节目和好莱坞电影的取景地，神奇的抓印造型山脉和倒塌的大枯树干让人仿佛置身于《侏罗纪公园》紧张刺激的真实场景中，你还有机会与微缩版复活节岛摩艾石像合影，途经《迷失》中Hurley打高尔夫球的球场，看一看《哥斯拉》留下的怪兽大脚印。 <br/> <br>2、【深山体验之旅：吉普车丛林越野】<br>坐上老式的军用吉普车，沿着蜿蜒的小路和起伏的山丘，来场热带雨林穿越吧！约90分钟的车程中，充满原始热带风情的哈基普雾（Hakipuu）山谷尽收眼底。游览过程中，你还将有机会短程步行到高台，俯瞰瓦胡岛东部海岸线和古代夏威夷鱼塘的美丽风光。 <br/> <br>3、【海洋体验之旅：迎风追浪】<br>踏上双体船，游览卡内奥赫海湾（Kaneohe Bay），你将离开古兰尼主园区，从Moli’i码头登上49人的双体船驶入Kaneohe海湾。在海面上您可以将整座古兰尼山尽收眼底，同时也有机会近距离接触Mokoli’i岛（又名“草帽岛”）。如果好的话，甚至可以从船上看到鲸鱼和海龟！一定要带上您的相机哦！ <br/> <br>备注：海洋巡游活动周日和美国公众假期不开放，9岁或以下儿童必须有监护人陪同参加。 <br/> <br>4、【3小时神秘岛活动】<br>神秘岛海滩是一个僻静的私人海滩，是一个放松自我，舒缓压力的好去处，是您夏威夷之行的选项之一。我们为您提供了各式各样的设备与器具，您可以放松的与大海来一次亲密接触！<br>您只需带上泳衣，浴巾，防晒霜以及相机，我们为您准备了丰富的海上活动！神秘岛上为您免费提供了香蕉船，皮划艇，独木舟，冲浪板，沙滩排球，乒乓球，羽毛球，凉席，吊床以及更多好玩的水上活动设施。或者您可以伴着海风在吊床上休息，或乘坐玻璃底船出海寻找海龟。神秘岛上设有更衣室和淋浴，建议您携带一件用于更换的衣服和毛巾。 <br/> <br>备注:玻璃底船周日不开放。 <br/> <br>5、【古代生态植物园】<br>古代生态植物园之旅给您一个机会深入了解古代夏威夷的文化和历史。您将会经过古兰尼的Moli’i热带花园。热带花园中不仅有夏威夷本土的植物，也有世界各地的植物花卉。您将会学习第一批夏威夷人是怎样将各种植物带上岛并成功种植。参观完热带花园后，您将有机会亲自品尝植物园中的水果。 <br/> <br>备注：9岁或以下儿童必须有监护人陪同参加。 <br/> <br>夏威夷海洋公园海豚邂逅 <br/> <br>凡是预定邂逅海豚节目，凭电子确认函入园即可特别获得价值10美金的Beachboy Lanai Food court 餐券。<br>游客可站在水深齐腰的平台上观察海豚表演。海豚会与游客玩耍，亲吻游客，甚至和游客一起“舞蹈”！如果天气允许，您还可以与海豚拍照留念。 <br/> <br>海豚邂逅入场时间：10:15 am/11:45 am/13:00 pm/14:30 pm（水中时间：30分钟）
1017617144	5	4	推荐餐厅【Wolfgang's Steakhouse】<br>由Wolfgang Zwiener一手创办的牛排餐厅，他曾于名震纽约餐饮界的牛排馆Peter Luger Steakhouse工作40余年，对厨艺上从无间断的精进，让沃尔夫冈牛排馆自成立以来形成独树一帜的牛排文化，无与伦比的美味征服了无数美食爱好者的味蕾，成为美国备受推崇的牛排馆之一。
1017617144	6	1	欧胡岛_国内出发地
1017617144	6	2	推荐活动：<br>【大岛一日游】<br>特色景点：<br>【夏威夷大岛：在热带滑雪】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br>【夏威夷火山国家公园：看火山熔岩】<br>来到大岛，夏威夷火山国家公园是必游景点。这里坐落着两座活火山茂纳洛亚火山（Mauna Loa）和基拉韦厄（Kilauea），毁灭与新生在此并存。站在巨大的火山口旁，看通红炽热的岩浆在火山湖中流淌，堪称大自然奇观。穿过历史悠久的熔岩通道，尽头又是一片葱郁繁茂的热带雨林，颇有柳暗花明又一村之感。<br>【希洛海湾黑沙滩：邂逅玳瑁和绿海龟】<br>大多数人对于夏威夷的印象是碧海白沙，而大岛由于火山活动频繁，造就了这里奇特的黑沙滩。光脚漫步在纯黑色的沙地上，触感竟然分外细腻柔软。入眼所及，清冽的海水和锃亮黝黑的岩石在阳光的照耀下形成鲜明有趣的对比，由于黑色的沙子能更好的吸收太阳光，趴在沙滩上进行日光浴也是十分悠闲愉快的享受。当地的两种珍惜动物——玳瑁和绿海龟也会时常出没此地晒太阳，快来与它们邂逅吧。<br>【彩虹瀑布：对彩虹许愿】<br>彩虹瀑布由左、右两道水流交汇而成，犹如一匹白练般从岩石顶端倾泻而下，落入水潭中激起层层水雾。再加上四周青翠茂盛的热带植物映衬，景色怡人。等到天气晴好时，瀑布的水雾在阳光的折射下形成了一道灿烂的彩虹天桥，横架在水潭上方，又给这幅山水画卷添上了绚丽多彩的一笔。
1024139739	9	5	行程酒店仅作推荐，您可以自主选择
1017617144	6	3	推荐餐厅【Roy's Waikiki】<br>Roy's 餐厅是夏威夷的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。建议提前1-2天订位。
1017617144	7	1	国内
1017617144	7	2	提前3小时送机前往机场，后搭乘航班返回国内。
1017617144	7	3	导游送机
1017617144	7	4	国内
1017617144	7	5	抵达国内，结束了此次美妙的夏威夷之旅！
1017617144	7	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
2918034	1	1	国内出发地_夏威夷
2918034	2	1	欧胡岛
2918034	2	2	如不需要升级套餐，请在下一步将默认份数更改为0，则您所预定的产品仅为机票+酒店套餐
2918034	2	3	请至少提前3小时自行前往机场办理登机手续<br/> 抵达夏威夷后，前往办理相关入境手续并提取行李
2918034	2	4	抵达夏威夷，导游接机后送往当地酒店办理入住。 <br/> 1.国际航班(MU/KE/NH/OZ)早上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机  <br/> <br>2.国际航班(CA/HA)晚上到达的客人,请在2号口出口集合,导游会穿蓝色Polo体桖举牌接机 <br/> <br>3.美国本土国内到达的客人,请到行李提取处跟导游汇合。我们导游会穿蓝色Polo体桖举牌接机 <br/> <br>注：接机为当地散拼，可能需要等到同航班其他客人全部出来后才能出发。
2918034	2	5	备注：<br>夏威夷酒店国际惯例，要下午15:00PM入住，如果酒店不能入住，请客人把行李寄存在酒店，之后自由活动。<br/>
2918034	3	1	欧胡岛
2918034	3	2	上午参加：珍珠港+市区游+珠宝博物馆参观。（行程参考时间7:30am-11:30am，以接机导游给到的行程确认单为准）<br>【珍珠港】位于美国夏威夷州欧胡岛上的海港，位于该州首府檀香山西方。东距火奴鲁鲁约10公里。面积89平方公里。港区掩蔽条件好，水域回旋余地大，为世界天然良港。土著夏威夷人称珍珠港为\\
2918034	3	3	夏威夷当地海岛珠宝展示馆参观
2918034	3	4	波利尼西亚文化中心
2918034	3	5	行程游览结束后驱车送往酒店。
2918034	4	1	欧胡岛
2918034	4	2	上午恐龙湾浮潜（含浮潜工具，门票自理）下午大环岛北岸精品游。特别包含夏威夷卡胡库风味虾餐（行程参考时间13:00pm-18:00pm，以接机导游给到的行程确认单为准）<br>
2918034	4	3	【恐龙湾】<br>恐龙湾Hanauma Bay是来夏威夷的游客喜欢去的潜水的地方之一。水浅，浪小，鱼多，风景美丽，那里有各种天然的珊瑚礁石和热带鱼类。恐龙湾是海底死火山，火山口的一面受海浪万年不变的拍击而倒塌，变成象马蹄的形状，所以又被戏称为马蹄湾。恐龙湾是中国人给起的名字，因为从海湾的一头远远望去，恐龙湾就像一头窝在海水中的恐龙。
2918034	4	4	特色虾餐
2918034	4	5	<br>游览欧胡岛的北岸， 这个是几乎是来自世界各地游客必去的夏威夷高人气线路，欧胡岛精华丽的海岸线，我们开车穿越帕里森林公路，一路观赏Ko'olau山脉，绿树成荫，然后来到Ko'olau山谷之中的一座悠静古庙—平等院（门票自理）。这座庙宇建于1968年，整座建筑没有一颗钉子，完整呈现了山谷空悠的自然之美，西安事变主角张学良先生和赵四女士就是葬在此处，大家可以到这里瞻仰一下这位改变中国历史的名人。离开Koolau 山脉我们会进入另一个夏威夷的Kualoa 山谷，美国总统奥巴马夫人在APPTEC会议期间就在此处宴请各国第一夫人，当你看到这山谷的时候一定会觉的似曾相识的感觉，侏罗纪公园，风语者，初恋50次和迷失都在那里拍摄的，这里是好莱坞导演的挚爱之地。之后前往 下 一站 MACADAMIANUT FARMOUTLET（夏威夷果农场），这 里你可品尝各种夏威夷土特产：火山 豆，咖啡等了解夏威 夷农产品 的种植情 况 ，增长相关 知识 。然后驾车前往KAHUKU ，在那里你可以品尝只有夏威夷才能吃到的KAHUKU甜虾之后前往北海岸北处的落日海滩，那是欧胡岛受欢迎的冲浪海滩冲浪者的天堂，是现代冲浪运动的起源地，每到冬季世界各地冲浪好手到此朝圣，并在此地一较高下，也就是世界冲浪锦标赛的官方指定比赛地点。下一站途径是总统奥巴玛喜欢的哈雷伊瓦小镇，每年回来度假，总统一家 都会 光顾这 里，展示第 一家 庭 的亲民，奥巴马女儿 喜欢那里的彩虹冰（途径）。后我们观光车会停在都乐菠萝园农场让 游客们下车拍照 ，沿途 一片农家田园风情。
2918034	4	6	行程结束后返回酒店，晚餐自理
2918034	5	1	欧胡岛
2918034	5	2	当天行程为二选一 古兰尼牧场体验之旅 或者 海洋公园（海豚邂逅）
2918034	5	3	今日游玩项目可自选（二选一） <br/> <br>古兰尼牧场：【自然与探险之旅】 <br/> <br>古兰尼牧场是每一位到夏威夷的游客都不容错过的景点之一。这里山峦叠嶂，树木葱郁，还有波光粼粼的大海和细白沙滩，清新优美的自然风光使其成为《侏罗纪公园》、《迷失》等诸多大片的拍摄地。再加上骑马、吉普车丛林越野、独木舟、双体船出海等花样繁多的娱乐项目，对于童心未泯的朋友们来说，简直就是探险大自然的不二去处。 <br/> <br>最近上演的《侏罗纪世界2》故事的中的努布拉岛，也是在夏威夷古兰尼牧场取景拍摄的。作为一个真正的侏罗纪系列影迷，如果想要去电影中的努布拉岛朝圣，想要化身电影的男主女主，亲身经历一下这个史前动物乐园，就不能错过古兰尼牧场这个好莱坞电影御用拍摄地。 <br/> <br>午餐：沙拉，韩式泡菜，鸡肉BBQ，牛肉BBQ，甜品，饭，饮料等自助餐，请以实际安排为准。 <br/> <br>【体验套餐】：安排【山谷体验之旅：游览好莱坞拍摄地】 【深山体验之旅：吉普车丛林越野】   【古代生态植物园】   午餐（如果有婴儿不能参加【深山体验之旅：吉普车丛林越野】项目公司会尽量安排【海洋体验之旅：迎风追浪】代替，如当天关闭则视客人自动放弃该行程） <br/> <br>1、【山谷体验之旅：游览好莱坞拍摄地】<br>如果你是好莱坞美剧控，牧场北半部的卡阿瓦山谷一定会令你惊叹不已。这里一直是无数热门电视节目和好莱坞电影的取景地，神奇的抓印造型山脉和倒塌的大枯树干让人仿佛置身于《侏罗纪公园》紧张刺激的真实场景中，你还有机会与微缩版复活节岛摩艾石像合影，途经《迷失》中Hurley打高尔夫球的球场，看一看《哥斯拉》留下的怪兽大脚印。 <br/> <br>2、【深山体验之旅：吉普车丛林越野】<br>坐上老式的军用吉普车，沿着蜿蜒的小路和起伏的山丘，来场热带雨林穿越吧！约90分钟的车程中，充满原始热带风情的哈基普雾（Hakipuu）山谷尽收眼底。游览过程中，你还将有机会短程步行到高台，俯瞰瓦胡岛东部海岸线和古代夏威夷鱼塘的美丽风光。 <br/> <br>3、【海洋体验之旅：迎风追浪】<br>踏上双体船，游览卡内奥赫海湾（Kaneohe Bay），你将离开古兰尼主园区，从Moli’i码头登上49人的双体船驶入Kaneohe海湾。在海面上您可以将整座古兰尼山尽收眼底，同时也有机会近距离接触Mokoli’i岛（又名“草帽岛”）。如果好的话，甚至可以从船上看到鲸鱼和海龟！一定要带上您的相机哦！ <br/> <br>备注：海洋巡游活动周日和美国公众假期不开放，9岁或以下儿童必须有监护人陪同参加。 <br/> <br>4、【3小时神秘岛活动】<br>神秘岛海滩是一个僻静的私人海滩，是一个放松自我，舒缓压力的好去处，是您夏威夷之行的选项之一。我们为您提供了各式各样的设备与器具，您可以放松的与大海来一次亲密接触！<br>您只需带上泳衣，浴巾，防晒霜以及相机，我们为您准备了丰富的海上活动！神秘岛上为您免费提供了香蕉船，皮划艇，独木舟，冲浪板，沙滩排球，乒乓球，羽毛球，凉席，吊床以及更多好玩的水上活动设施。或者您可以伴着海风在吊床上休息，或乘坐玻璃底船出海寻找海龟。神秘岛上设有更衣室和淋浴，建议您携带一件用于更换的衣服和毛巾。 <br/> <br>备注:玻璃底船周日不开放。 <br/> <br>5、【古代生态植物园】<br>古代生态植物园之旅给您一个机会深入了解古代夏威夷的文化和历史。您将会经过古兰尼的Moli’i热带花园。热带花园中不仅有夏威夷本土的植物，也有世界各地的植物花卉。您将会学习第一批夏威夷人是怎样将各种植物带上岛并成功种植。参观完热带花园后，您将有机会亲自品尝植物园中的水果。 <br/> <br>备注：9岁或以下儿童必须有监护人陪同参加。 <br/> <br>夏威夷海洋公园海豚邂逅 <br/> <br>凡是预定邂逅海豚节目，凭电子确认函入园即可特别获得价值10美金的Beachboy Lanai Food court 餐券。<br>游客可站在水深齐腰的平台上观察海豚表演。海豚会与游客玩耍，亲吻游客，甚至和游客一起“舞蹈”！如果天气允许，您还可以与海豚拍照留念。 <br/> <br>海豚邂逅入场时间：10:15 am/11:45 am/13:00 pm/14:30 pm（水中时间：30分钟）
2918034	5	4	推荐餐厅【Wolfgang's Steakhouse】<br>由Wolfgang Zwiener一手创办的牛排餐厅，他曾于名震纽约餐饮界的牛排馆Peter Luger Steakhouse工作40余年，对厨艺上从无间断的精进，让沃尔夫冈牛排馆自成立以来形成独树一帜的牛排文化，无与伦比的美味征服了无数美食爱好者的味蕾，成为美国备受推崇的牛排馆之一。
2918034	6	1	欧胡岛
1936768	2	7	哈雷伊瓦小镇Haleiwa Town——日落海滩Sunset Beach（约12公里）从哈雷伊瓦小镇前往日落海滩的沿途会有一些做大虾排档餐厅或餐饮车，这是您解决午餐的不二之选
1936768	3	1	夏威夷
1936768	3	2	上午一觉睡到自然醒，调整时差。后全天自由活动。<br>建议行程：
1936768	3	3	威基基区域酒店——波利尼西亚文化村Polynesian Cultural Center（需门票，约55公里）<br><br>波利尼西亚文化中心是夏威夷具有代表特色的地方文化活动，由于距离威基基有一定距离，您也可选择参加当地的拼团，预订信息详见下一步。<br>
1936768	3	4	海龟湾度假酒店Turtle Bay Resort-古兰尼牧场Kualoa Ranch（需门票，约30公里）<br>威基基区域酒店——古兰尼牧场Kualoa Ranch（需门票，约38公里）<br>古兰尼牧场分为一日游和半日游，同文化村一样距离较远，您也可以选择参加当地的拼团，预订信息详见下一步。
1936768	3	5	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
1936768	4	1	夏威夷
1936768	4	2	建议行程：
1936768	4	3	您可沿着沿东部海滨公路一路向南行驶，沿途美景美不胜收。神庙谷地处葱翠的山谷之中，其景点是一个日本佛寺及进入寺庙前的圣钟，门票价格非常便宜。<br><br>
2918034	6	2	推荐活动：<br>【大岛一日游】<br>特色景点：<br>【夏威夷大岛：在热带滑雪】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br>【夏威夷火山国家公园：看火山熔岩】<br>来到大岛，夏威夷火山国家公园是必游景点。这里坐落着两座活火山茂纳洛亚火山（Mauna Loa）和基拉韦厄（Kilauea），毁灭与新生在此并存。站在巨大的火山口旁，看通红炽热的岩浆在火山湖中流淌，堪称大自然奇观。穿过历史悠久的熔岩通道，尽头又是一片葱郁繁茂的热带雨林，颇有柳暗花明又一村之感。<br>【希洛海湾黑沙滩：邂逅玳瑁和绿海龟】<br>大多数人对于夏威夷的印象是碧海白沙，而大岛由于火山活动频繁，造就了这里奇特的黑沙滩。光脚漫步在纯黑色的沙地上，触感竟然分外细腻柔软。入眼所及，清冽的海水和锃亮黝黑的岩石在阳光的照耀下形成鲜明有趣的对比，由于黑色的沙子能更好的吸收太阳光，趴在沙滩上进行日光浴也是十分悠闲愉快的享受。当地的两种珍惜动物——玳瑁和绿海龟也会时常出没此地晒太阳，快来与它们邂逅吧。<br>【彩虹瀑布：对彩虹许愿】<br>彩虹瀑布由左、右两道水流交汇而成，犹如一匹白练般从岩石顶端倾泻而下，落入水潭中激起层层水雾。再加上四周青翠茂盛的热带植物映衬，景色怡人。等到天气晴好时，瀑布的水雾在阳光的折射下形成了一道灿烂的彩虹天桥，横架在水潭上方，又给这幅山水画卷添上了绚丽多彩的一笔。
2918034	6	3	推荐餐厅【Roy's Waikiki】<br>Roy's 餐厅是夏威夷的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。建议提前1-2天订位。
2918034	7	1	欧胡岛
2918034	7	2	推荐活动【亚特兰蒂斯潜水艇】深入80英尺的海底世界，探秘古老的沉船遗迹，欣赏各种海底生物。不用“湿身”，就能畅游海底王国，不会游泳的朋友也无需担心
2918034	7	3	推荐【夏威夷幻像魔术草裙舞晚宴】<br>
2918034	8	1	欧胡岛_国内出发地
2918034	8	2	交通：可乘坐公交433至Lumiaina St + Waikele Center站下车即可。如您选择公共交通前往，请及时留意末班车情况。
2918034	8	3	outlets里有多家餐饮店可供您选择。
2918034	9	1	国内
2918034	9	2	提前3小时送机前往机场，后搭乘航班返回国内。
2918034	9	3	导游送机
2918034	9	4	国内
2918034	9	5	抵达国内，结束了此次美妙的夏威夷之旅！
2918034	9	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
5516095	1	1	国内-洛杉矶
5516095	2	1	洛杉矶
5516095	2	2	搭乘航班从国内飞往洛杉矶。
5516095	2	3	【如何搭乘免费班车】<br>接驳车位于LAX机场行李盘外，显示为“Hotel & Courtesy Shuttle”的红色显示屏下。在车身或车头印有各家酒店名称。单程行驶时间为10-15分钟。建议每件行李支付1美元小费。
5516095	3	1	洛杉矶
5516095	4	1	洛杉矶
5516095	5	1	洛杉矶-拉斯维加斯
5516095	6	1	拉斯维加斯
5516095	7	1	拉斯维加斯
5516095	7	2	建议前往世界七大奇景之一的科罗拉多大峡谷一日游。您可在成功预订后添加我们的一日游产品。
5516095	8	1	拉斯维加斯-夏威夷
5516095	8	2	建议前往Las Vegas North Premium Outlets奥特莱斯血拼购物。您可在拉斯主道上搭乘观光巴士DEUCE抵达，一日票大约7美金。
5516095	9	1	夏威夷
5516095	9	2	请自行预订拉斯维加斯飞往夏威夷航班。（此产品中不含美国内陆机票）
5516095	10	1	夏威夷
5516095	10	2	上午前往珍珠港参观第二次大战日本偷袭原址。观看珍贵的历史纪录片，并乘船前往参观被日军炸沉的亚历山大号战舰残骸。随后送往Waikele Premium自由购物。（此日行程可能根据实际情况与下面一日对换）
5516095	11	1	夏威夷-国内
5516095	11	2	上午小环岛半日游，中午赠送特级牛排餐，下午Ala Moana自由购物。<br>
5516095	12	1	国内
5516095	12	2	上午送往机场，搭乘航班返回国内。
5516095	12	3	国内
5516095	12	4	回到温馨的家
5516095	12	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1936768	1	1	居住地-夏威夷
1936768	2	1	夏威夷
1936768	2	2	今日自行前往国际机场国际出发大厅办理登机，后达成航班飞往夏威夷，抵达后办理相关入境手续。<br><br>携程柜台位于机场1号团队出口右边，如有问题可至柜台咨询。<br>
1936768	2	3	建议行程：<br><br>根据您出行前所预订的车组，前往柜台取车，夏威夷地区租车租赁条款及使用说明详见附加产品内。<br>
1936768	2	4	机场Honolulu International Airport——珍珠港Peral Harbor（约15公里）<br>珍珠港距离机场非常近，由于酒店大多需要下午3点才能办理入住，抵达夏威夷的第一站不妨先去举世闻名的珍珠港一探究竟。首先您可在珍珠港景区拍照留念，这里有二次世界大战遗留下来的大炮、鱼雷、战舰等等。亚利桑那战舰纪念馆是免费的，但是需要很早的去排队取票，或在他们官网上提前预约。密苏里号战舰纪念馆（需门票）是二次世界大战日本宣布签署无条件投降书的地点，这也是二战的重要标志事件之一。
1936768	2	5	珍珠港Peral Harbor——都乐菠萝园Dole Plantation（约22公里）<br>从珍珠港往北部行驶途径的第一个景点就是都乐菠萝园，这里每年生产大量的菠萝提供本岛居民以及出口国外。您可乘坐小火车（需门票）参观菠萝种植园，亦可品尝到美味的菠萝冰淇淋。
1936768	2	6	都乐菠萝园Dole Plantation——哈雷伊瓦小镇Haleiwa Town（约11公里）<br>哈雷伊瓦小镇是冲浪中心，更是本土风情、乡村格调，以及商店、餐厅和美术馆的集结地。木造的小店座落其中，知名的彩虹雪花冰也是诞生于此，镇上目前有H. Miura、Matsumoto’s、Aoki’s等3家杂货商店，以贩卖彩虹刨冰而闻名，以Matsumoto’s为，络绎不绝的游客大排长龙，不妨入境随俗尝一杯洒上色彩缤纷的彩虹冰吧！欧巴马喜欢的汉堡店\\
1024139739	10	1	莫斯科-出发地
1936768	4	4	神庙谷Valley of the Temples——奥特莱斯Waikele Premium Outlets（约30公里）<br>今天应该还有很多充裕的时间，不妨顺路去outlets里血拼一把。<br>
1936768	4	5	奥特莱斯Waikele Premium Outlets——威基基区域酒店（约30公里）<br>根据您出行前所选择的酒店，于下午3点之后可办理入住手续。<br>
1936768	4	6	威基基区域酒店——钻石头山Diamond Head State Monument（约6公里）<br>钻石头山是威基基的象征，驱车可以抵达钻石头山中部的纪念碑，前往山顶必须要徒步往返，傍晚在这里可以观赏到壮丽的威基基日落。
1936768	4	7	推荐餐厅【Bubba Gump Shrimp】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站
1936768	5	1	夏威夷
1936768	5	2	建议行程：
1936768	5	3	威基基区域酒店——卡哈拉高级住宅区Kahala——恐龙湾Hanauma Bay——喷泉洞Halona Blowhole——大风口Nuuanu Pali Lookout——白沙滩（全程约61公里）<br>从威基基的东面出发，一路可以途径上述人气景点。如您对浮潜（需门票）感兴趣则可以在恐龙湾多停留一段时间，这里可是夏威夷富盛名的浮潜圣地，是浮潜爱好者的天堂。<br>
1936768	5	4	推荐餐厅【Roy's Waikiki】Roy's 餐厅是夏威夷有名的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。丰盛大餐配上优质的服务，不容错过，建议提前1-2天订位。交通<br>：可乘坐公交8、19、20、23、42至Kalia Rd + Saratoga Rd站下车，向东南方步行10分钟即可。<br>
1936768	6	1	夏威夷
1936768	6	2	推荐餐厅【California Pizza Kitchen】美国有名披萨连锁店，起源于加利福尼亚的比弗利山庄，已有近30年的历史。饮料可以免费续杯。交通：可乘坐公交2L、22、E路Kalakaua Ave + Opp Seaside Ave站下车即可。
1936768	7	1	夏威夷
1936768	7	2	推荐餐厅【Fook Yuen Seafood Restaurant 】距离威基基海滩不远，餐厅很火爆，尤其受国人欢迎，饭点经常需要等位。味道是熟悉的中餐味道，服务也很不错，招牌的龙虾新鲜美味、选择很多。
1936768	8	1	夏威夷-居住地
1936768	8	2	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
1936768	9	1	居住地
1936768	9	2	今早将结束夏威夷的行程早上退房后可以直接前往机场<br>威基基区域酒店-机场（约13公里） 
1936768	9	3	居住地
1936768	9	4	抵达温馨的家园，结束全部行程。 
1936768	9	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
5516072	1	1	国内-洛杉矶
5516072	2	1	洛杉矶
5516072	2	2	搭乘航班从国内飞往洛杉矶。
5516072	2	3	【如何搭乘免费班车】<br>接驳车位于LAX机场行李盘外，显示为“Hotel & Courtesy Shuttle”的红色显示屏下。在车身或车头印有各家酒店名称。单程行驶时间为10-15分钟。建议每件行李支付1美元小费。
5516072	3	1	洛杉矶
5516072	3	2	早上8:30于酒店大堂门口集合，搭乘GO123绿线拼车前往环球影城Universal Studio一日游。大约17:00结束游览。（此日建议小费6美金/人）<br>环球影城门票建议提前网上预订或于影城门口现买。
5516072	4	1	洛杉矶-拉斯维加斯
5516072	5	1	拉斯维加斯
5516072	5	2	特别优惠：399元即可换购位于MGM酒店内的大型歌舞表演KA秀。
5516072	6	1	拉斯维加斯
5516072	6	2	建议前往世界七大奇景之一的科罗拉多大峡谷一日游。您可在成功预订后添加我们的一日游产品。
5516072	7	1	拉斯维加斯-夏威夷
5516072	7	2	建议前往Las Vegas North Premium Outlets奥特莱斯血拼购物。您可在拉斯主道上搭乘观光巴士DEUCE抵达，一日票大约7美金。
5516072	8	1	夏威夷
5516072	8	2	请自行预订拉斯维加斯飞往夏威夷航班。（此产品中不含美国内陆机票）
5516072	8	3	Tropicana距离拉斯维加斯机场约2.5公里，搭乘出租车是性价比的方式，行驶时间大约10分钟，价格20美金左右。<br>抵达夏威夷后导游接机送往酒店。
5516072	9	1	夏威夷
5516072	9	2	上午前往珍珠港参观第二次大战日本偷袭原址。观看珍贵的历史纪录片，并乘船前往参观被日军炸沉的亚历山大号战舰残骸。随后送往Waikele Premium自由购物。（此日行程可能根据实际情况与下面一日对换）
5516072	10	1	夏威夷-国内
5516072	10	2	上午小环岛半日游，中午赠送夏威夷特色牛排餐，下午Ala Moana自由购物。<br>
5516072	11	1	国内
5516072	11	2	上午送往机场，搭乘航班返回国内。
5516072	11	3	国内
5516072	11	4	安全抵达国内<br>
5516072	11	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1655500	1	1	出发地_夏威夷
1655500	2	1	夏威夷
1655500	2	2	办理登机:请自行直接机场国际出发大厅办理登机<br><br>航班信息:由出发地前往夏威夷（具体航班信息请在预订下一步中查看）<br><br>晚餐：飞机上<br><br>第二天早餐:飞机上<br><br>
1655500	2	3	抵达美国，办理相关入境手续，导游接机。<br>搭乘MU571航班抵达，赠送以下【市区游】行程，其余航班直接送往酒店。<br>温馨提醒：接送机服务仅限入住威基基区域酒店客人选择。
1655500	2	4	可自行选择入住酒店。<br>温馨提示：根据国际惯例，酒店入住时间为当地时间下午3点。
1655500	2	5	温馨提示：接送机服务及以下行程仅推荐，如不需要请在下一步默认行程中，将份数更改为0，则您所预订的产品仅含机票+酒店。 
1655500	3	1	夏威夷
1655500	3	2	今天，推荐您去珍珠港走走逛逛吧。（当天行程为【夏威夷珍珠港半日游】，客人可根据喜好选择日期） <br>温馨提醒：选择此行程日期请勿与航班日期重叠。
1655500	3	3	同前一天入住酒店
1024680990	9	2	根据航班时间前往机场，返回国内
1655500	3	4	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。
1655500	4	1	夏威夷
1655500	4	2	（当天行程为【夏威夷小环岛半日游】，客人可根据喜好选择日期） <br>温馨提醒：选择此行程日期请勿与航班日期重叠。
1655500	4	3	同前一天入住酒店
1655500	4	4	推荐餐厅【Bubba Gump Shrimp】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站
1655500	5	1	夏威夷
1655500	5	2	今天全天您可以自由安排活动，或选择其他丰富的当地活动。<br>推荐活动：【古兰尼牧场】<br>【90分钟活动自选】<br>1、山谷体验之旅：游览令人叹为观止的卡阿瓦山谷ka'a'awa，体验户外的牧场，农田，观好莱坞大片外景拍摄地如：侏罗纪公园Jurassic Park，迷失Lost，哥斯拉Godzilla等。<br>2、深山体验之旅：一起探索古兰尼丰富的历史和传统，乘坐六轮瑞士军用吉普车去探索原始的哈基普雾山谷Hakipu'u，沿着丛林小道通过河床和陡峭的山丘，探险热带丛林。<br>3、海洋体验之旅：乘坐巴士参观种植了各种不同的热带水果的茉莉依花园，随后游览者瓦胡岛上保存得完好的古代夏威夷鱼塘，享受美丽和宁静的环境，再从神秘岛出发乘坐双体船游览卡内奥赫海湾Kaneohe Bay，欣赏背面的怡人景色。双体船游览活动周日和美国公众假期不开放。<br>【3小时神秘岛活动】<br>神秘岛海滩是一个僻静的私人海滩，是一个放松自我，舒缓压力的好去处。提供不同的海上娱乐设施如划皮艇，划独木舟，以及立浆冲浪等，还提供不同球类活动如沙滩排球，羽毛球，乒乓球等。<br> <br>早餐、午餐、晚餐敬请自理。<br>  <br>
1655500	5	3	同前一天入住酒店（或可自行选择其他入住酒店）
1655500	5	4	推荐餐厅【Roy's Waikiki】Roy's 餐厅是夏威夷有名的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。丰盛大餐配上优质的服务，不容错过，建议提前1-2天订位。交通<br>：可乘坐公交8、19、20、23、42至Kalia Rd + Saratoga Rd站下车，向东南方步行10分钟即可。<br>
1655500	6	1	夏威夷
1655500	6	2	今天全天您可以自由安排活动，或选择其他丰富的当地活动。<br>推荐行程【大岛一日游】：到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。<br><br>早餐、午餐、晚餐敬请自理。
1655500	6	3	同前一天入住酒店（或可自行选择其他入住酒店）
1655500	6	4	推荐餐厅【California Pizza Kitchen】美国有名披萨连锁店，起源于加利福尼亚的比弗利山庄，已有近30年的历史。饮料可以免费续杯。交通：可乘坐公交2L、22、E路Kalakaua Ave + Opp Seaside Ave站下车即可。
1655500	7	1	夏威夷
1655500	7	2	今天全天您可以自由安排活动，或选择其他丰富的当地活动。<br>推荐活动：【波利尼西亚文化中心】<br>【套餐简介】：<br>1、接送+演出+自助晚餐：畅游七个村落、独木舟水上舞蹈音乐表演、体验圣殿访客中心之旅、欣赏“HA～生命之歌”、自助餐每日名额有限。<br>自助晚餐菜单：新鲜水果，素菜沙拉（切碎的奶酪，胡萝卜条，橄榄，黄瓜片，小玉米，葵花籽，熏肉，菠萝块），当地特色hukilau沙拉，日本酱汤，甘蓝猪肉卷，炸鸡，红烧鲯鳅鱼，茂宜混合蔬菜，肉汁土豆泥，米饭，菠萝面包，巧克力/椰子蛋糕，百事可乐，咖啡和凉茶（以餐厅实际提供的菜色为准）。<br>2、接送+演出+阿里鲁奥餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、阿里鲁奥自助晚餐 、“HA～生命之歌”中排座位。<br>3、接送+演出+大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、大使牛肋排自助晚餐 、“HA～生命之歌”前排座位、“HA～生命之歌”特别导览。<br>4、接送+演出+鲁奥大使套餐：畅游七个村落、独木舟水上舞蹈音乐表演、圣殿访客中心之旅、鲁奥宴花环欢迎式、园区导览、大使级夏威夷贝壳花环、纪念礼品袋、阿里鲁奥自助晚餐、“HA～生命之歌”特别导览、“HA～生命之歌”前排座位。<br>5、接送+演出+超级大使套餐：畅游七个村落、各村落表演VIP专属座位、专属独木舟村落游、独木舟水上舞蹈音乐表演、VIP专属座位、特制夏威夷贝壳花环、夏威夷花环欢迎式、个人专属导游园区导览、精致餐点、后台参观、“HA～生命之歌” VIP贵宾席、圣殿访客中心之旅、表演节目DVD纪念光盘。<br>注意：<br>1）由于该行程抵达文化村的时间在15：00-15：30左右，且每个村落的表演时间都不一样，所以可能无法带您逛完所有的村落，用餐时间也会根据每天的人数等调整。请您谅解。<br>2）鲁奥大使套餐的用餐时间比其他套餐的用餐时间早30分钟左右，所以参观部落村及观看演出的时间会减少。请您谅解。<br><br>早餐、午餐、晚餐敬请自理。<br><br>
1655500	7	3	同前一天入住酒店（或可自行选择其他入住酒店）
1655500	7	4	推荐餐厅【Fook Yuen Seafood Restaurant 】距离威基基海滩不远，餐厅很火爆，尤其受国人欢迎，饭点经常需要等位。味道是熟悉的中餐味道，服务也很不错，招牌的龙虾新鲜美味、选择很多。
1655500	8	1	夏威夷
1655500	8	2	您可选择漫步于喧闹的街市，领略当地的街头文化；或者和海风、沙滩、阳光来上一次亲密接触，让自己的身体学着放松和享受！<br><br>早餐、午餐、晚餐敬请自理。<br><br>
1655500	8	3	同前一天入住酒店（或可自行选择其他入住酒店）
1655500	8	4	推荐餐厅【The Pineapple Room by Alan Wong】网红同款，泛亚洲菜系餐厅，，据说都是有机蔬菜和肉食。交通：可乘坐公交5、6、8、17、18至Kona St + Opp Keeaumoku St (FS)站下车即可。<br>
1655500	9	1	夏威夷
1655500	9	2	今天全天您可以自由安排活动<br>推荐活动：【茂宜岛一日游】：以山谷的秀丽而著称茂宜岛，十六世纪捕鲸时期形成的捕鲸镇-LAHAINA TOWN。\\
1655500	9	3	同前一天入住酒店（或可自行选择其他入住酒店）
1655500	9	4	推荐餐厅【Fook Yuen Seafood Restaurant 】距离威基基海滩不远，餐厅很火爆，尤其受国人欢迎，饭点经常需要等位。味道是熟悉的中餐味道，服务也很不错，招牌的龙虾新鲜美味、选择很多。
1655500	10	1	夏威夷
1655500	10	2	今天全天您可以自由安排活动<br><br>早餐、午餐、晚餐敬请自理<br><br>
1655500	10	3	同前一天入住酒店（或可自行选择其他入住酒店）
1655500	10	4	推荐餐厅【Bubba Gump Shrimp】在这里你会看到很多与“阿甘”有关的东西，包括餐桌上手写的“阿甘名言”，菜单上标明的阿甘虾的N种吃法。交通：可搭乘公交车至Ala Moana Bl + Ala Moana Center站
1655500	11	1	夏威夷_出发地
1655500	11	2	今天全天您可以自由安排活动<br><br>早餐、午餐、晚餐敬请自理<br><br>
1655500	11	3	同前一天入住酒店（或可自行选择其他入住酒店）
1024680990	9	3	国内
1024680990	9	4	抵达出发地，结束愉快的夏威夷+西海岸之行。
1655500	11	4	推荐餐厅【Roy's Waikiki】Roy's 餐厅是夏威夷有名的厨师Roy创办的，汇合日本和西餐的夏威夷fusion菜系。丰盛大餐配上优质的服务，不容错过，建议提前1-2天订位。交通<br>：可乘坐公交8、19、20、23、42至Kalia Rd + Saratoga Rd站下车，向东南方步行10分钟即可。<br>
1655500	12	1	出发地
1655500	12	2	体验过夏威夷的热情。今天前往机场，乘机返回。（具体航班信息请在预订下一步中查看） 
1655500	12	3	敬请自理<br><br>您可以抓紧最后的时间为您的亲朋好友购买夏威夷当地的纪念品。<br>
1655500	12	4	出发地
1655500	12	5	抵达目的地，结束此次美妙的夏威夷之旅！ 
1655500	12	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1023217846	1	1	国内出发地_夏威夷
1023217846	2	1	欧胡岛
1023217846	2	2	请至少提前3小时自行前往机场办理登机手续<br> 抵达夏威夷后，前往办理相关入境手续并提取行李
1023217846	2	3	自由规划行程建议您单独预订接送机服务
1023217846	2	4	备注：<br>夏威夷酒店通常在下午15:00PM后办理入住；如您抵达酒店时无法办理入住，请客人把行李寄存在酒店后开启自由度假时光。
1023217846	3	1	欧胡岛
1023217846	3	2	自由活动。伴着太平洋微风，暂时忘却各种不如意，拥抱眼前的碧海蓝天，并微笑着前行。<br>【波利尼西亚文化村】<br>波利尼西亚文化中心，将在专业导游的帶領下参观七個不同文化特色的部落，了解波利尼西亚原居民的风土人情。晚間享受丰盛的美食水果自助餐。餐后欣赏由一百多位演員参加的大型夏威夷传统歌舞表演，及活人吞火的惊险火把表演。（感恩节和圣诞节不开放）
1023217846	3	3	推荐餐厅【Nico's Pier 38】<br>地址：1129 N. Nimitz Hwy, Honolulu, HI 96817
1023217846	4	1	夏威夷_家
1023217846	4	2	自由活动。<br>【大岛一日游】<br>到了夏威夷，不能不去大岛。岛上气候变化多端，全世界共有13种气候带，大岛就包含了其中11个。在岛上，你可以在同一天上山滑雪，下海游泳，还能看到热带雨林、沙漠和流淌着红色岩浆的活火山。
1023217846	4	3	推荐餐厅【Waikiki Brewing Company】<br>地址：​​1945 Kalakaua Avenue, Honolulu, HI 96815
1023217846	5	1	抵达
1023217846	5	2	请至少提前3小时自行前往机场办理登机手续
1023217846	5	3	抵达
1023217846	5	4	抵达，结束短暂而又难忘的夏威夷之旅。
1023217846	5	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024680990	1	1	出发地—夏威夷
1024680990	2	1	夏威夷
1024680990	2	2	搭乘国际航班飞往夏威夷。
1024680990	2	3	抵达夏威夷—檀香山，前往酒店。<br>提示：为了您游玩方便，请尽量选择威基基区域酒店。
1024680990	2	4	三餐请自理。
1024680990	3	1	夏威夷
1024680990	3	2	全天自由活动。
1024680990	3	3	自由活动，行程仅作推荐。
1024680990	3	4	威基基区域酒店——卡哈拉高级住宅区Kahala——恐龙湾Hanauma Bay——喷泉洞Halona Blowhole——大风口Nuuanu Pali Lookout——白沙滩（全程约61公里）<br>从威基基的东面出发，一路可以途径上述人气景点。如您对浮潜（需门票）感兴趣则可以在恐龙湾多停留一段时间，这里可是夏威夷富有盛名的浮潜圣地，是浮潜爱好者的天堂。
1024680990	3	5	三餐请自理。
1024680990	4	1	夏威夷
1024680990	4	2	全天自由活动。
1024680990	4	3	自由活动，行程仅作推荐。
1024680990	4	4	威基基区域酒店——珍珠港Peral Harbor（约20公里）<br>来到夏威夷必定要去探访举世闻名的珍珠港。首先您可在珍珠港景区拍照留念，这里有二次世界大战遗留下来的大炮、鱼雷、战舰等等。亚利桑那战舰纪念馆是免费的，但是需要很早的去排队取票，或在他们官网上提前预约。密苏里号战舰纪念馆（需门票）是二次世界大战日本宣布签署无条件投降书的地点，这也是二战的重要标志事件之一。
1024680990	4	5	三餐请自理。
1024680990	5	1	夏威夷—洛杉矶
1024680990	5	2	全天自由活动。
1024680990	5	3	自由活动，行程仅作推荐。
1024680990	5	4	威基基区域酒店——波利尼西亚文化村Polynesian Cultural Center（需门票，约55公里）<br>波利尼西亚文化中心是夏威夷具有代表特色的地方文化活动，由于距离威基基有一定距离，您也可选择参加当地的拼团，预订信息详见下一步。
1024680990	6	1	洛杉矶
1024680990	6	2	搭乘内陆段航班，前往天使之城—洛杉矶。
1024680990	6	3	自由活动。<br>推荐景点：<br>1、【比弗利山庄】：这里是举世闻名的全球富豪心目中的梦幻之地，作为洛杉矶市内有名的城中城，这里有全球闻名的商业街，也云集了好莱坞影星们的众多豪宅，同样还作为世界影坛的圣地。比弗利山庄每年都会吸引无数来自世界各地的观光客，好奇地在大街小巷探索。<br>2、【圣塔莫尼卡海滩】圣塔莫妮卡是洛杉矶的海滩之一，位于十号公路的尽头，拥有洛杉矶的码头嘉年华，包括过山车、海盗船、空中悬挂等等游艺项目。这里还有奶油厚奶昔、简朴的海贝项链，它们来自码头边一排排的零食小屋和饰品店。而本地渔民为整个场景增添了一道靓丽的风景。
1024680990	7	1	洛杉矶
1024680990	7	2	全天自由活动。
1024680990	7	3	自由活动，行程仅作推荐。
1024680990	7	4	跟随奥斯卡获奖电影《爱乐之城》走遍天使洛杉矶！打卡男女主角停留过的 天使铁路小火车+复古中央市场+格里菲斯天文台！<br>您也可选择自驾或参加当地的拼团，预订信息详见下一步。
1024680990	7	5	三餐请自理。
1024680990	8	1	洛杉矶—国内
1024680990	8	2	全天自由活动。
1024680990	8	3	自由活动，行程仅作推荐。
1024680990	8	4	三餐请自理。
1024680990	9	1	国内
1024680990	9	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024685033	1	1	出发地—夏威夷
1024685033	2	1	欧胡岛
1024685033	2	2	搭乘国际航班飞往夏威夷。
1024685033	2	3	抵达夏威夷—檀香山，前往酒店。<br>提示：为了您游玩方便，请尽量选择威基基区域酒店。
1024685033	2	4	三餐请自理。
1024685033	3	1	欧胡岛
1024685033	3	2	全天自由活动。
1024685033	3	3	自由活动，行程仅作推荐。
1024685033	3	4	威基基区域酒店——卡哈拉高级住宅区Kahala——恐龙湾Hanauma Bay——喷泉洞Halona Blowhole——大风口Nuuanu Pali Lookout——白沙滩（全程约61公里）<br>从威基基的东面出发，一路可以途径上述人气景点。如您对浮潜（需门票）感兴趣则可以在恐龙湾多停留一段时间，这里可是夏威夷富有盛名的浮潜圣地，是浮潜爱好者的天堂。
1024685033	3	5	三餐请自理。
1024685033	4	1	欧胡岛—大岛
1024685033	4	2	全天自由活动。
1024685033	4	3	自由活动，行程仅作推荐。
1024685033	4	4	威基基区域酒店——珍珠港Peral Harbor（约20公里）<br>来到夏威夷必定要去探访举世闻名的珍珠港。首先您可在珍珠港景区拍照留念，这里有二次世界大战遗留下来的大炮、鱼雷、战舰等等。亚利桑那战舰纪念馆是免费的，但是需要很早的去排队取票，或在他们官网上提前预约。密苏里号战舰纪念馆（需门票）是二次世界大战日本宣布签署无条件投降书的地点，这也是二战的重要标志事件之一。
1024685033	4	5	三餐请自理。
1024685033	5	1	大岛
1024685033	5	2	根据航班时间飞往大岛。
1024685033	5	3	全天自由活动。
1024685033	5	4	自由活动，行程仅作推荐。
1024685033	6	1	大岛—洛杉矶
1024685033	6	2	自由活动。
1024685033	6	3	三餐请自理。
1024685033	7	1	洛杉矶
1024685033	7	2	根据航班时间，飞往天使之城洛杉矶。<br>Tips：洛杉矶与夏威夷时差为+3小时。
1024685033	7	3	全天自由活动。
1024685033	7	4	自由活动，行程仅作推荐。
1024685033	7	5	三餐请自理。
1024685033	8	1	洛杉矶
1024685033	8	2	全天自由活动。
1024685033	8	3	自由活动，行程仅作推荐。<br>环球影城交通提示：搭乘地铁红线在Universal City站下，出站不远就有免费接驳车，5分钟即可到达。
1024685033	8	4	三餐请自理。
1024685033	9	1	洛杉矶—国内
1024685033	9	2	全天自由活动。
1024685033	9	3	自由活动，行程仅作推荐。<br>交通信息：位于洛杉矶市中心东南约45公里，开车前往大约40分钟。
1024685033	9	4	三餐请自理。
1024685033	10	1	抵达
1024685033	10	2	根据航班时间前往机场，返回国内
1024685033	10	3	抵达
1024685033	10	4	返回温馨的家。
1024685033	10	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
71801	1	1	国内—东京
71801	2	1	东京（追寻MV的故事  晴空塔---谷中银座--高圆寺商店街）
71801	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
71801	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
71801	2	4	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
71801	2	5	交通：从新宿商区可步行至酒店~
71801	3	1	可选购富士山+河口湖一日游（打卡富士急乐园）
71801	3	2	您可以在酒店餐厅内享用丰富的自助早餐。
71801	3	3	赏樱名所
71801	3	4	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 s
71801	3	5	新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
71801	3	6	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
71801	3	7	乘坐JR山手线、东京Metro地铁南北线，至驹込站下，N14出口出，步行约7分钟即达；<br>乘坐都营地铁三田线，至千石站下，I14出口出，步行约10分钟即达。
71801	3	8	JR山手线、常磐线日暮里站徒步5分钟；<br>东京地下铁千代田线千駄木站徒步5分钟
71801	3	9	JR中央总武线高圆寺站下车，南口出，步行五分钟左右即可进入商圈。
36838	3	1	可选购富士山+河口湖一日游
36838	3	2	请至酒店内餐厅享用自助早餐<br>
36838	3	3	赏樱名所
36838	3	4	乘坐山手線到达上野，换乘東京メトロ銀座線到达浅草
1024279184	3	8	行程酒店仅作推荐，您可以自主选择
71801	3	10	日本东京百年老店和牛料理餐厅 盛田屋<br>这家拥有百年传承的老店盛田屋如今已有10家分店。其美味与口碑共存一直深受日本人喜爱。这家位于丸之内的盛田屋是现代的装修风格，大理石的地板、白炽吊灯以及白色的泥墙，透过高雅的落地玻璃窗，可以欣赏到东京的美丽夜景。黑色的木桌搭配白色皮革座椅，简约而不失高贵，令餐厅有一种简单素净的气氛。
71801	3	11	交通：搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
71801	4	1	东京（原宿街头 说好不哭MV网红奶茶店machi经典打卡）
71801	4	2	可以享用酒店内的自助早餐，或者在便利店购买
71801	4	3	新宿西口（平成观光候车室）<br>地址：東京都新宿区西新宿１－２１－１１　山銀ビル（bill)４F <br>集合时间：08:15
71801	4	4	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。
71801	4	5	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>搭乘旅游巴士返回东京新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
71801	4	6	交通：从新宿商圈可步行返回酒店。
71801	5	1	东京—国内
71801	5	2	可以在酒店内享用丰富的自助早餐
71801	5	3	地铁大江户线至赤羽桥站，赤羽桥口出步行约5分钟
71801	5	4	JR山手线至原宿站
71801	5	5	网红奶茶店——麦吉（machi machi!）是一家颜值超高的饮品小店，在近日在东京原宿开设了第一间。<br>地址：东京都涩谷区神宫前1-11-6 ラフォーレ原宿 2F GOOD MEAL MARKET内<br>这家店主打高颜值的少女心风格，光是在店门口就安排了几把与众不同的椅子，上面搭配着极简手绘风格的地图，非常适合拍照留念了。麦吉的Logo主要是一个小狗的团，看起来相当活泼，设计感十足，或许正是如此可爱的风格一下子就捕获了大部分消费者的心呢！再加上白色冲浪板、手写品牌名、黄铜玻璃灯饰，给适合当下年轻人们对于流行饮品的其他需求。<br><br>〰️<br><br>手摇饮品是麦吉的主打，整个品牌强调的就是创新和天然的理念，全店共分为五大系列，现萃纯茶、芝士奶盖、波波气泡、鲜奶拿铁和鲜榨水果。为了能够保持奶茶的几本口味，店内的原料就由纽西兰出品芝士、台南柳营鲜奶和日本奶油一起打底，这样做出的浓香奶茶怎么会让人不心动呢！再搭配上丝滑奶酪、正宗仙草冻和梅子果冻，不仅仅是从外表来说颜值动人，就连口味上也带着俏皮可爱的质感。
71801	5	6	在新宿站搭乘丸之内线到荻窪駅北口，换乘公交五站即可到达
71801	5	7	叙叙苑由创业以来一直坚持为顾客提供高质料理与优质的服务。菜单以「和牛」为中心，食材全由专人严选出来。配上无烟烧肉的设备与优雅的装潢，令您享受到日本美妙的用餐。
71801	5	8	东京—国内
71801	5	9	您可以在酒店餐厅内享用丰富的自助早餐。
71801	5	10	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
71801	5	11	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
71801	5	12	和幸(新宿店)<br>地址： 新宿区西新宿6-5−1 B1F<br>电话： +81-3-33547311<br><br>米其林星星炸猪排<br>美味的炸猪排连锁店，和幸的猪排使用少量的猪油或黄油进行油炸，这样炸出来的猪排外皮香脆，肉质松软无比，食后令人回味无穷。套餐一般在一千日元以上，包含了炸猪排、沙拉、味增汤、蒸蛋、米饭等等，吃完挺有饱腹感的。米饭和生菜可以随意添加。店面不大，服务员很少，不过上菜速度倒是很快。
71801	5	13	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
71801	5	14	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
71801	5	15	乘坐舒适的班机返回国内，结束本次愉快的旅途
71801	5	16	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
36838	1	1	国内—东京
36838	2	1	东京
36838	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
36838	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
36838	2	4	步行前往即可～
36838	2	5	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
36838	3	5	浅草聚乐是一家坐落在浅草寺附近的家庭式餐厅。在日本，家庭式餐厅是以家庭为客户群体的餐厅，菜单也是以各种套餐为主。这里不仅有日式料理，还有西式菜肴和中餐。强烈推荐牛肉寿喜烧天妇罗生鱼片套餐。这个菜又有寿喜烧，又有天妇罗和生鱼片。一次性把日本料理的3大菜系都给吃遍了。含税1500日元，性价比还是挺高的。s
36838	3	6	须贺神社位于新宿区一带，创建于1634年，因为《你的名字》而名噪一时。<br>自从电影上映之后，吸引了众多粉丝来朝圣，特别是神社前的一个十字路口，也是知名场景的取景地。<br>主要奉祀须贺大神和稻荷大神，神社内保存有珍贵的《三十六歌仙绘》，是新宿区的指定有形文化遗产。
36838	3	7	JR山手线/京滨东北线，滨松町站北口出，出门就可以看见塔，之后沿道路向增上寺前进，穿过增上寺即可到达，总路程步行约15分钟<br>地铁大江户线至赤羽桥站，赤羽桥口出步行约5分钟
36838	3	8	于 东京塔 3层，是人气动画《海贼王》的首 个大型主题公园，园内设有草帽海贼团各成员的主题活动区。 ·体验形式多种多样，有漫画展览、人物雕塑展、360°电影播放仪、VR体验，还有可以和cosplay人物互动的小游戏等。 ·公园内还设有主题餐厅和咖啡店，提供只有在这里才能吃到的特色美食；手办商店还将推出限量版的纪念品。 ·推荐香吉士为主题的“香吉士吃到饱餐厅”，只需付2000日元就可以大口吃烤肉。 TIPS 1. 日本国内购票方法：可在7-Eleven便利店购买预售票。日本以外地区的购票方法：可于官网购买预售票。 2. 主题乐园的停车场毗邻东京铁塔，停车1小时收取600日元，之后每30分钟加收300日元。停车场营业时间为9:00-22:00（21:45停止进场）。 3. 园区内全区禁止吸烟。 4. 酒类、饮品、便当类、三脚架等摄影辅助器材、一切危险物品等禁止携带入园。现场表演中请勿使用相机、摄影机、手机等纪录影像或录音。
36838	4	1	东京
36838	4	2	可以享用酒店内的自助早餐，或者在便利店购买
36838	4	3	新宿西口（平成观光候车室）<br>地址：東京都新宿区西新宿１－２１－１１　山銀ビル（bill)４F <br>集合时间：08:15
36838	4	4	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。
36838	4	5	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>搭乘旅游巴士返回东京新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
36838	4	6	交通：从新宿商圈可步行返回酒店。
36838	5	1	东京
36838	5	2	可以在酒店内享用丰富的自助早餐
36838	5	3	在新宿站搭乘丸之内线到荻窪駅北口，换乘公交五站即可到达
36838	5	4	搭乘JR从新宿坐小田急线至豪德寺站下车，步行15分钟
36838	5	5	建于1480年，寺院规模很大，偏僻清幽，少有游人打扰。<br>·招福猫的发源地。传说井伊直孝跟着猫跑到寺中避雨，听了寺里和尚的法谈又觉得十分投缘，自此豪德寺成了井伊家的菩提寺。<br>·寺里建造了招猫殿，供奉招猫观音。招猫殿旁也放了一千多只招福猫，萌态十足。<br>·每年春季，整个寺院内的樱花灿若云霞，也是一个可以避开人群，安静赏樱花的好去处。
36838	5	6	JR山手线/日比谷线-惠比寿站东口，步行5分钟。
36838	5	7	代官山与惠比寿相邻，位于东京都涩谷区，属于东京中高阶级的住宅区，气氛高雅。<br>整个区域内的商铺也很松散，节奏较为缓慢，虽然给不了人疯狂购物的感觉，但是它能给你一种平静的心情，让你有时间、有心情去欣赏一件东西，是东京比较小资与有情调的地方。<br>车站附近是出售各种日用商品的市场，生活杂货，各种优雅、品味跟个性化的商品，尤其受到年轻女性的欢迎。
36838	5	8	叙叙苑由创业以来一直坚持为顾客提供高质料理与优质的服务。菜单以「和牛」为中心，食材全由专人严选出来。配上无烟烧肉的设备与优雅的装潢，令您享受到日本美妙的用餐。
36838	6	1	东京—国内
36838	6	2	交通：乘地铁大江户线至汐留，换乘百合鸥线(YURIKAMOME) 在\\
36838	6	3	地址：东京都东京都中央区筑地6-21-2<br><br>寿司大是筑地市场著 名的两家店之一，与大和寿司齐名。<br>·店内寿司都是现场捏制，吃完一个做一个，很大程度的保证了食材的新鲜。<br>·寿司师傅都超热情，会介绍每个寿司使用的材料，个别师傅还会中文介绍。<br>·这里只有十几个座位，每天凌晨四点就会排起长队，要做好长时间等待的准备。
36838	6	4	交通：在筑地站搭乘东京地下铁“日比谷”线至银座站，换乘东京地下铁“有乐町”线至新桥站，再换乘“海鸥线”抵达台场海滨公园站。
36838	6	5	台场海滨公园站下车步行2分钟 /在\\
36838	6	6	地址：港区台场1-7-1 <br>日本一家网红咖喱蛋包饭店，酱汁都特别浓郁，猪排外脆里嫩，很大一块，而且不会是面粉面包糠这种裹出来的大，日式的蛋包饭的蛋皮很嫩很嫩，而且稍带些湿润的感觉~！
36838	6	7	交通：“台场站”下车，步行2分钟抵达。
36838	6	8	交通：百合鸥线“台场站”下车步行约3分钟/临海线“东京电讯港（Tokyo Teleport）站步行约5分钟<br><br>休息：每周一休息，周一为节假日时则周二休息<br><br>门票：免费（展望台成人550日元，中小学生300日元）
36838	6	9	交通：搭乘海鸥线至“新桥站”，后换乘银座线至“银座站”。
36838	6	10	地址：東京都 中央区 銀座 8-7 銀座ナイン2号館 2F<br><br>日本知名连锁餐厅，提供做 法各异、滋味不同的蟹肉大餐，这家分店位于银座，人气非常旺。
36838	6	11	东京—国内
36838	6	12	您可以在酒店餐厅内享用丰富的自助早餐。
36838	6	13	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
36838	6	14	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
36838	6	15	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
36838	6	16	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
36838	6	17	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
36838	6	18	乘坐舒适的班机返回国内，结束本次愉快的旅途
36838	6	19	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1009991988	1	1	国内—东京
1009991988	2	1	东京
1009991988	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
1009991988	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
1009991988	2	4	步行前往即可～
1009991988	2	5	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
1009991988	2	6	交通：从新宿商区可步行至酒店~
1009991988	3	1	东京艺术之旅
1009991988	3	2	您可以在酒店餐厅内享用丰富的自助早餐。
1009991988	3	3	交通：搭乘JR山手线至原宿站，后步行抵达。
1009991988	3	4	地址： 涩谷区神宫前4-31 原宿TK大厦1F<br>营业时间：周一至周五11:00-22:00，周六周日节假日11:00-21:30
1009991988	3	5	交通：可步行抵达。
1009991988	3	6	交通：可步行抵达。
1009991988	3	7	地址：涩谷区神宫前1-13?21<br>营业时间：周一至周五10:45-24:00，周六周日节假日 10:00-24:00
1009991988	3	8	交通：搭乘JR山手线至新宿站，后步行抵达。
1009991988	4	1	东京—国内
1009991988	4	2	可以在酒店内享用丰富的自助早餐
1009991988	4	3	JR中央线 三鹰站 南口 步行约15分钟<br>JR中央线、京王井之头线 吉祥寺站 南口 步行约15分钟<br>从三鹰站或吉祥寺站下车后分别可以乘坐巴士前往美术馆，三鹰站的话从南口坐巴士，在“三鹰之森吉卜力美术馆”下车，吉祥寺站从南口坐巴士，在“万助桥”下车。
1009991988	4	4	日本动漫在全世界都有很高的声望，三鹰之森吉卜力美术馆是由动画大师宫崎骏在其工作室的基础上亲自设计的。<br>B1层的影像展示室“土星座”，放映只有在这里才能欣赏到的吉卜力工作室出品的动漫短剧。只有日语版本，但动漫无国界哦。<br>1楼大厅介绍动画的制作原理，2楼主要展示宫崎峻及工作人员的工作场景，有许多细致的参考资料，从飞机、船舶到街景、人物等，还能看到手工绘本。<br>美术室内一律不允许拍照，但是室外可以随意拍，有许多熟悉的场景：《魔女宅急便》中的黑猫；“红猪”先生、《天空之城》剧中的大机器人等。<br>在纪念品商店可以买到各种吉卜力相关的周边：龙猫公仔、千与千寻拼图、天空之城雕刻、印有动画场景的雨伞等，是外面买不到的。<br>这里的主题餐厅也非常受欢迎，在充满动画氛围的餐厅里品尝动漫里的创意美食，就像是进入了童话世界一般。
1009991988	4	5	自东京Metro地铁日比谷线「六本木站」步行0分钟(通路直达)：<br>自都营地铁大江户线「六本木站」步行4分钟，「麻布十番站」步行5分钟；<br>自JR涩谷站搭乘都营01系统、都营涩88系统公共汽车(涩谷～新桥)于「EX影院六本木前」站下车
1009991988	4	6	设立在六本木之丘中的森美术馆，是东京现在前卫的美术馆之一。<br>·因为它让之前分散的当代艺术有了一处集中的展厅，所以开业时曾是东京艺术界的一大盛事。<br>·这里没有固定的馆存，但是每月都会有新的主题展，无论是设计思路还是展出内容都代表了日本艺术的尖 端。
1009991988	4	7	赏醉美夜樱
1009991988	4	8	叙叙苑由创业以来一直坚持为顾客提供高质料理与优质的服务。菜单以「和牛」为中心，食材全由专人严选出来。配上无烟烧肉的设备与优雅的装潢，令您享受到日本美妙的用餐。
1009991988	4	9	交通：搭乘东京地下铁丸之内线至新宿站，后步行抵达酒店。
1009991988	4	10	东京—国内
1009991988	4	11	您可以在酒店餐厅内享用丰富的自助早餐。
1009991988	4	12	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1009991988	4	13	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1019194061	5	6	东京—国内
1009991988	4	14	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1009991988	4	15	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1009991988	4	16	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1009991988	4	17	乘坐舒适的班机返回国内，结束本次愉快的旅途
1009991988	4	18	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
2556409	1	1	出发地—东京—东京迪士尼度假区
2556409	2	1	迪士尼乐园欢乐游
2556409	2	2	搭乘航班飞往东京，抵达后直接前往迪士尼酒店入住<br><br>可由机场直接搭乘利木津巴士前往迪士尼。<br><br>若抵达时间较晚建议第二天在前往迪士尼乐园。
2556409	2	3	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
2556409	2	4	交通：利木津巴士可直接送至酒店门口。
2556409	3	1	东京（浅草—东京晴空塔—上野公园）
2556409	3	2	您可以在酒店餐厅内享用丰富的自助早餐。
2556409	3	3	交通：从酒店可步行或者搭乘酒店提供的接驳巴士。
2556409	3	4	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
2556409	3	5	交通：从迪士尼海洋可步行或者搭乘酒店提供的接驳巴士。
2556409	4	1	可选购富士山+河口湖一日游
2556409	4	2	您可以在酒店餐厅内享用丰富的自助早餐。
2556409	4	3	东京迪士尼园区至浅草寺，换乘方法：<br>1、先乘坐京叶线至东京站；<br>2、换乘银座线·浅草行至浅草站。 
2556409	4	4	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 <br>s
2556409	4	5	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
2556409	4	6	浅草寺搭乘银座线到上野站，车程约5分钟。
2556409	4	7	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼老 字号店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种做 法，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。
2556409	4	8	搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
2556409	5	1	东京
2556409	5	2	您可以在酒店餐厅内享用丰富的自助早餐。
2556409	5	3	新宿西口（平成观光候车室）<br>地址：東京都新宿区西新宿１－２１－１１　山銀ビル（bill)４F <br>集合时间：08:15
2556409	5	4	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。
2556409	5	5	搭乘旅游巴士返回东京新宿。
2556409	5	6	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>交通：搭乘JR山手线至新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
2556409	5	7	交通：从新宿商圈可步行返回酒店。
2556409	6	1	东京—国内
2556409	6	2	交通：在新宿站搭乘东京地下铁“丸之内”线至银座站，后换乘东京地下铁“日比谷”线至筑地站下车。后步行抵达。
2556409	6	3	地址：东京都东京都中央区筑地6-21-2<br><br>寿司大是筑地市场的两家店之一，与大和寿司齐名。<br>·店内寿司都是现场捏制，吃完一个做一个，很大程度的保证了食材的新鲜。<br>·寿司师傅都超热情，会介绍每个寿司使用的材料，个别师傅还会中文介绍。<br>·这里只有十几个座位，每天凌晨四点就会排起长队，要做好长时间等待的准备。
2556409	6	4	交通：在筑地站搭乘东京地下铁“日比谷”线至银座站，换乘东京地下铁“有乐町”线至新桥站，最后换乘“海鸥线”抵达台场海滨公园站。
1019194061	5	7	您可以在酒店餐厅内享用丰富的自助早餐。
2632836	4	3	交通：在新宿站搭乘JR中央线抵达东京站，后换乘JR京叶线至舞滨站~
2556409	6	5	地址：港区台场1-7-1 <br>日本一家网红咖喱蛋包饭店，酱汁都特别浓郁，猪排外脆里嫩，很大一块，而且不会是面粉面包糠这种裹出来的大，日式的蛋包饭的蛋皮很嫩很嫩，而且稍带些湿润的感觉~！
2556409	6	6	交通：“台场站”下车，步行2分钟抵达。
2556409	6	7	交通：搭乘电车百合海鸥号至青海站下车，步行约3分钟即到。或可直接步行抵达。
2556409	6	8	交通：搭乘海鸥线至“新桥站”，后换乘银座线至“银座站”。
2556409	6	9	地址：東京都 中央区 銀座 8-7 銀座ナイン2号館 2F<br><br>日本知名连锁餐厅，提供做 法各异、滋味不同的蟹肉大餐，这家分店位于银座，人气非常旺。
2556409	6	10	交通：搭乘东京地下铁丸之内线至新宿站，后步行抵达酒店。
2556409	6	11	东京—国内
2556409	6	12	您可以在酒店餐厅内享用丰富的自助早餐。
2556409	6	13	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
2556409	6	14	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
2556409	6	15	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
2556409	6	16	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
2556409	6	17	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
2556409	6	18	乘坐舒适的班机返回国内，结束本次愉快的旅途
2556409	6	19	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1019194061	1	1	国内—东京
1019194061	2	1	东京—镰仓
1019194061	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
1019194061	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
1019194061	2	4	步行前往即可～
1019194061	2	5	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
1019194061	2	6	交通：从新宿商区可步行至酒店~
1019194061	3	1	镰仓—东京
1019194061	3	2	可以在酒店内享用丰富的自主早餐，或者去便利店购买<br>
1019194061	3	3	早餐可以在酒店享用，也可以去附近的便利店或者小餐馆解决。<br>从东京前往镰仓建议乘坐小田急电铁，该电铁与镰仓的江之电有通票，可一日内往返于新宿与镰仓以及江之电的无限次乘坐，到藤泽站或者江之岛站即可换乘江之电。另单独购买江之电1日券为610日元，不含东京往返。
1019194061	3	4	搭乘江之岛电铁在长谷站下车步行10分钟，在长谷站周边有许多饮食店，可以根据自己喜好吃一顿午餐。
1019194061	3	5	交通：从长谷寺步行前往
1019194061	3	6	交通：步行前往酒店。<br><br>酒店不仅可以品尝地道的日本料理，还可以在Le Trianon 餐厅不仅能一边看着窗外蓝色海洋的景致，一边品尝新鲜食材烹制的正宗法式料理。<br>
1019194061	4	1	迪士尼乐园
1019194061	4	2	可以看着海景，听着海浪声，在酒店享用丰富的自助早餐
1019194061	4	3	推荐早上去，人相对来说比较少，可以拍摄经典的灌篮高手场景，乘坐江之岛电铁到镰仓高校前站下车即可。
1019194061	4	4	乘坐江之岛电铁在江之岛站下车
1019194061	4	5	在江ノ島乘坐江ノ島電鉄?藤沢行到达藤沢，换乘小田急江ノ島線快速急行到达新宿。
1019194061	4	6	新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。
1019194061	4	7	浅草寺搭乘银座线到上野站，车程约5分钟。
1019194061	4	8	交通：搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
1019194061	5	1	东京—国内
1019194061	5	2	<br>请至酒店内餐厅享用自助早餐
1019194061	5	3	交通：在新宿站搭乘JR中央线抵达东京站，后换乘JR京叶线至舞滨站~
1019194061	5	4	<br>优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
1019194061	5	5	交通：在舞滨站搭乘JR京叶线抵达东京站，后换乘JR中央线至新宿站~出站后步行抵达。
1019194061	5	8	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1019194061	5	9	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1019194061	5	10	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1019194061	5	11	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1019194061	5	12	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1019194061	5	13	乘坐舒适的班机返回国内，结束本次愉快的旅途
1019194061	5	14	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1018919513	1	1	国内—东京—箱根
1018919513	2	1	箱根
1018919513	2	2	乘坐舒适的国际航班到达日本
1018919513	2	3	您可以选择机场利木津巴士或者JR express抵达新宿
1018919513	2	4	东京市区至箱根<br>1、小田急浪漫特快车、从新宿出发即可直达箱根小田原站的特快列车，座位舒适、车窗角度更分明，平稳而流畅的行驶过程中，关东地方景致在窗外如卷轴画一般铺展开来。当人们仍迷醉于沿途风光时，仅85分钟小田急浪漫特快车已优雅地抵达箱根小田原站。<br>2、从东京站搭乘新干线至箱根小田原站，后换乘登山电车至箱根汤本车站。如前往强罗，需在汤本车站下车后换乘汤本至强罗登山电车。每小时1~3班。 <br><br>Tips：您可以将大件行李寄存在东京酒店，只需携带部分换洗衣物和必要装备前往。<br>避免在乘坐公共交通时发生托运行李的烦恼~~
1018919513	2	5	餐饮：您可在酒店内享用一顿丰盛的怀石料理。
1018919513	2	6	交通：在元箱根港搭乘箱根巴士抵达箱根汤本站，后步行至酒店，步行时间约5分钟。
1018919513	3	1	箱根—东京
1018919513	3	2	您可以在酒店餐厅内享用丰富的自助早餐。
1018919513	3	3	从箱根汤本车站乘坐箱根登山巴士（T路线）约24分钟，在“川向·小王子博物馆前”汽车站下车即是 
1018919513	3	4	地址：日本神奈川県足柄下郡箱根町宮ノ下296<br>交通：搭乘箱根登山铁道至宫丿下站，下车后步行10分钟抵达~<br>午餐营业时间：11:30-13:30<br><br>日本人气电视剧《孤独美食家》中介绍的餐厅，特的牛排饭~值得一试~<br>Tips：抵达后，需要先在门口的纸上写上自己的名字用来排队，等开门后店主会根据姓名的顺序请各位进店用餐~各位请写英文名或者用同音的平假名代替自己的名字，不要写中文哦~同时，如果你想尝尝这个美味，请一定尽早过去排队，限量提供可不是闹着玩哦~
1018919513	3	5	搭乘箱根登山列车至早云山站，换乘箱根空中缆车抵达大涌谷站~ <br>建议购买箱根周游券~~~
1018919513	3	6	搭乘箱根空中缆车至桃源台站。
1018919513	3	7	交通：可以在箱根汤本站外搭乘温泉巴士抵达酒店。
1018919513	4	1	东京（浅草—东京晴空塔—上野公园）
1018919513	4	2	您可以在酒店餐厅内享用丰富的自助早餐。
1018919513	4	3	汤本车站至御殿场outlets<br>可在汤本巴士站搭乘巴士直达御殿场outlet。<br>注意：巴士时间为每天4班，巴士出发参考时间：08：57；09：10；13：01；13：20。 
1018919513	4	4	御殿场奥特莱斯美食广场中有非常多的当地料理，您可以自由选择。
1018919513	4	5	如天气良好，御殿场奥特莱斯可以远眺富士山全景哦~
1018919513	4	6	交通：1、可搭乘箱根巴士返回箱根汤本站，后搭乘小田急浪漫号直达东京新宿站。<br>2、可在御殿场奥特莱斯搭乘高速巴士抵达东京站。
1018919513	4	7	交通：搭乘JR山手线抵达涩谷站。
1018919513	4	8	地址：东京都涩谷区樱丘町28-2三笠大楼 <br><br>高太郎是主打创意料理的居酒屋，装修非常精致，常年人气十足。主厨以日本各地精选的食材来打造创意料理，酒单非常有特色，令人有耳目一新的感觉。 
1018919513	4	9	搭乘东京东横线至涩谷站，后换乘JR山手线至新宿站。 
1018919513	5	1	东京迪士尼度假区
1018919513	5	2	您可以在酒店餐厅内享用丰富的自助早餐。
1018919513	5	3	新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
1018919513	5	4	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 <br>s
1018919513	5	5	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
1018919513	5	6	浅草寺搭乘银座线到上野站，车程约5分钟。
1021931014	5	1	东京—国内
1024279184	4	1	圣彼得堡
1018919513	5	7	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼老 字号店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种制作方法，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。
1018919513	5	8	搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
1018919513	6	1	东京—国内
1018919513	6	2	您可以在酒店餐厅内享用丰富的自助早餐。
1018919513	6	3	交通：在新宿站搭乘JR中央线抵达东京站，后换乘JR京叶线至舞滨站~
1018919513	6	4	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
1018919513	6	5	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
1018919513	6	6	交通：在舞滨站搭乘JR京叶线抵达东京站，后换乘JR中央线至新宿站~
1018919513	6	7	东京—国内
1018919513	6	8	您可以在酒店餐厅内享用丰富的自助早餐。
1018919513	6	9	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1018919513	6	10	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1018919513	6	11	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1018919513	6	12	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1018919513	6	13	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1018919513	6	14	乘坐舒适的班机返回国内，结束本次愉快的旅途
1018919513	6	15	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
2632836	1	1	国内—东京
2632836	2	1	东京
2632836	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
2632836	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
2632836	2	4	步行前往即可～
2632836	2	5	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
2632836	2	6	交通：从新宿商区可步行至酒店~
2632836	3	1	东京迪士尼度假区
2632836	3	2	您可以在酒店餐厅内享用丰富的自助早餐。
2632836	3	3	新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
2632836	3	4	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 s
2632836	3	5	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
2632836	3	6	浅草寺搭乘银座线到上野站，车程约5分钟。
2632836	3	7	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼老 字号店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种制作方法，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。
2632836	3	8	交通：搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
2632836	4	1	东京-大阪
2632836	4	2	您可以在酒店餐厅内享用丰富的自助早餐。
1022963926	5	6	抵达后莫斯科的司机将接您前往酒店
2632836	4	4	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
2632836	4	5	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
2632836	4	6	交通：在舞滨站搭乘JR京叶线抵达东京站，后换乘JR中央线至新宿站~
2632836	5	1	大阪-伏见稻荷大社--清水寺、三年坂二年坂--八坂神社、花见小路--返回大阪
2632836	5	2	您可以在酒店餐厅内享用丰富的自助早餐。
2632836	5	3	交通：1）从新宿站乘坐JR中央线到达东京站；2）在东京站乘坐新干线，从东京站直达新大阪站，约2小时40分钟左右。单程票价14000日元左右，折合人民币约900元。
2632836	5	4	交通：从新大阪站下来后，乘坐大阪地下铁御堂筋线，直接从新大阪站到难波站。下车后步行即可到达酒店，办理入住手续，如您到的时间还未到酒店check in时间，可将行李寄存在前台，然后出去游玩觅食了。
2632836	5	5	交通：步行至道顿崛美食街~
2632836	5	6	地址：大阪市中央区道頓堀1-7-26<br><br>金龙拉面”是日本排名第二的拉面，以巨大的立体中国龙型作为招牌，五家分店全集中在道顿堀，内部装潢虽谈不上漂亮，但红色基调的开放式“小吃”风格，以及榻榻米的座面，会让你体会到纯朴的日本式风格。秘制醇厚的猪骨汤是其特色，另外还免费提供泡菜、韭菜（盐好的）之类的东西，让客人随意加入面中，随便食用。
2632836	5	7	交通：心斋桥站搭乘御筋膛线抵达淀屋桥站，换乘京阪本线抵达天满桥站，后步行抵达。
2632836	5	8	地址：日本大阪府大阪市中央区日本橋1丁目21<br>交通：在大阪城公园站搭乘大阪环状线抵达日本桥站，后步行抵达黑门市场<br><br><br>来到大阪，那必定是要尝试一下当地的河豚10吃料理~<br>正规经营的河豚店厨师都是要考执照的，所以尽管放心去吃吧~~~！<br>
2632836	5	9	黑门市场和难波站这两个站之间有地下商业街相连，直线距离才500米。如果体力够的话，一路走马观花地逛过去最多也就20分钟。
2632836	6	1	日本环球影城一日游
2632836	6	2	享用一顿丰盛的早餐后，步行到难波站，搭乘御堂筋线到梅田站，然后换乘JR前往京都站，大约需要1小时30分钟左右。
2632836	6	3	从京都站搭乘阪急线到清水五条站下车，步行约10分钟到清水寺。
2632836	6	4	逛完清水寺后可以顺道去三年坂二年坂游玩。
2632836	6	5	寻一家路边小店品尝地道料理，看着墙上斑驳的光影，体验古都千年历史，恍若隔世。
2632836	6	6	餐后慢慢步行至祗园，兴致高的话可以进行和服换装，漫步在祗园老街，感受古都风情。也可以顺路去八坂神社，花见小路漫步。
2632836	6	7	返回京都站坐JR到大阪。乘坐JR到大阪至梅田站换乘地铁御堂筋线至难波（なんば）站下车抵达南海瑞士酒店。
2632836	6	8	您可以在酒店附近找一家拉面店，品尝正宗的关西拉面。
2632836	7	1	关西机场奥特莱斯&归国
2632836	7	2	在酒店享用早餐，之后从大阪难波站坐阪神なんば線到西九条站，换乘ＪＲゆめ咲線(桜島線)到环球影城站（ユニバーサルシティ），耗时21分钟，价格是200+160日元。<br>
2632836	7	3	留出充足时间，在环球影城与家人一起畅玩，共享欢乐<br><br>进入环球影城，享受1整天的亲子玩乐，8大游乐区域满足您和孩子各种玩乐需求！<br>推荐选购产品内附环球影城门票，直接扫码入园无需换票，方便快捷！<br>除门票外，产品内附多种fastpass，您可根据希望游玩的项目自行选择，缩短排队时间，留足充分快乐！<br><br><br><br>午餐请在大阪环球影城园区内解决，日料、意大利、烧烤、主题餐厅，8大园区每个都有自己的招牌料理餐厅，您可自由选择，如需提前查看，
2632836	7	4	愉快地玩乐一天之后，可以在环球影城门口的京阪环球影城都市酒店享用World World Buffet”自助晚餐或京阪环球影城塔楼酒店享受“The Garden”自助晚餐，产品内已附预定链接，您可直接大快朵颐，补充1天营养，充分休息。
2632836	7	5	关西机场奥特莱斯&归国
2632836	7	6	在酒店享用早餐
2632836	7	7	居住地-难波-关西机场临空奥特莱斯<br>（交通方式：地下铁&南海电铁，1、乘坐地铁到达难波站（瑞士南海酒店可直接从第2步看起）；2.难波站换乘南海电铁特急Lapid-β，临空城站下车即到。）<br><br>吐血推荐，日本非常大的奥特莱斯！网络国际和日本的品牌店，高中低档次具备，全是当下很流行的品牌，折扣低至三折，而且款式超新，上个月的新货就会拿过来打折卖！回国前淘货的不二之选。（出示护照免消费税8%，银联付款又可免5%，相当划算）
2632836	7	8	奥特莱斯--奥特莱斯园区内有多家饮食店可供自由选择。
2632836	7	9	关西机场奥特莱斯-关西国际机场<br>（交通方式：JR或南海电铁或巴士，1、奥特莱斯距离机场仅一站路，JR或南海电铁都可直接到达，2、奥特莱斯到机场也有免费巴士接驳）<br><br>关西机场是此行最后一站。如果来得早可以先在机场内的店逛逛，有MUJI、优衣库等品牌，也有百元店和一些日本纪念品和Laox机场店。<br>之后办登机牌托运（请尽量提前2小时），完毕后出关即可见到Kansai Duty Free，AAS等多家免税店和多家品牌商店如Cartier，CHANEL，TIFFANY & CO.，BVLGARI，MONTBLANC BOUTIQUE等。高级化妆品、免税烟酒、零食都可以在此处大买特买。<br>关西机场是有副楼的，中间都用接驳电车接驳，中间耗时大概5分钟。登机口在副楼的客人在购物前请提前看好时间以免误机。
2632836	7	10	乘坐舒适的国际航班，从关西机场回家，结束本次愉快的关西之旅。 
2632836	7	11	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1017168449	1	1	国内—东京
1017168449	2	1	东京
1017168449	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
1017168449	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
1017168449	2	4	百选赏樱名所 步行前往即可～
1017168449	2	5	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
1017168449	2	6	交通：从新宿商区可步行至酒店~
1017168449	3	1	可选购富士山+河口湖一日游
1017168449	3	2	可以在酒店内享用丰富的自助早餐，或者在便利店购买种类繁多的美食
1017168449	3	3	百选赏樱名所 浅草寺搭乘银座线到上野站，车程约5分钟。
1017168449	3	4	新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
1017168449	3	5	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。s
1017168449	3	6	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。樱花季赏樱好去处
1017168449	3	7	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼老 字号店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种做 法，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。
1017168449	3	8	交通：搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
1017168449	4	1	东京迪士尼度假区
1017168449	4	2	可以享用酒店内的自助早餐，或者在便利店购买
1017168449	4	3	新宿西口（平成观光候车室）<br>地址：東京都新宿区西新宿１－２１－１１　山銀ビル（bill)４F <br>集合时间：08:15
1017168449	4	4	富士山赏樱花
1017168449	4	5	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。
1017168449	4	6	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>搭乘旅游巴士返回东京新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
1017168449	4	7	交通：从新宿商圈可步行返回酒店。
1017168449	5	1	东京
1017168449	5	2	可以在酒店内享用丰富的自助早餐，或者在便利店购买种类繁多的美食
1017168449	5	3	交通：在新宿站搭乘JR中央线抵达东京站，后换乘JR京叶线至舞滨站~
1017168449	5	4	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
1017168449	5	5	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
1017168449	5	6	交通：在舞滨站搭乘JR京叶线抵达东京站，后换乘JR中央线至新宿站~
1017168449	6	1	东京
1017168449	6	2	可以在酒店内享用丰富的自助早餐
1017168449	6	3	搭乘JR从新宿坐小田急线至豪德寺站下车，步行15分钟
1017168449	6	4	建于1480年，寺院规模很大，偏僻清幽，少有游人打扰。<br>·招福猫的发源地。传说井伊直孝跟着猫跑到寺中避雨，听了寺里和尚的法谈又觉得十分投缘，自此豪德寺成了井伊家的菩提寺。<br>·寺里建造了招猫殿，供奉招猫观音。招猫殿旁也放了一千多只招福猫，萌态十足。<br>·每年春季，整个寺院内的樱花灿若云霞，也是一个可以避开人群，安静赏樱花的好去处。
1017168449	6	5	JR山手线/日比谷线-惠比寿站东口，步行5分钟。
1017168449	6	6	代官山与惠比寿相邻，位于东京都涩谷区，属于东京中高阶级的住宅区，气氛高雅。<br>整个区域内的商铺也很松散，节奏较为缓慢，虽然给不了人疯狂购物的感觉，但是它能给你一种平静的心情，让你有时间、有心情去欣赏一件东西，是东京比较小资与有情调的地方。<br>车站附近是出售各种日用商品的市场，生活杂货，各种优雅、品味跟个性化的商品，尤其受到年轻女性的欢迎。
1017168449	6	7	叙叙苑由创业以来一直坚持为顾客提供高质料理与优质的服务。菜单以「和牛」为中心，食材全由专人严选出来。配上无烟烧肉的设备与优雅的装潢，令您享受到日本美妙的用餐。
1017168449	6	8	网红打卡
1017168449	7	1	东京—国内
1017168449	7	2	在新宿站搭乘东京地下铁“丸之内”线至银座站，后换乘东京地下铁“日比谷”线至筑地站下车。后步行抵达。
1021931014	5	2	交通：在新宿站搭乘东京地下铁“丸之内”线至银座站，后换乘东京地下铁“日比谷”线至筑地站下车。后步行抵达。
1011208034	3	6	交通：搭乘箱根登山铁道抵达强罗站，需换乘另一部登山列车，抵达强罗公园站。
1023450960	8	6	出发地
1017168449	7	3	地址：东京都东京都中央区筑地6-21-2<br><br>寿司大是筑地市场的两家店之一，与大和寿司齐名。<br>·店内寿司都是现场捏制，吃完一个做一个，很大程度的保证了食材的新鲜。<br>·寿司师傅都超热情，会介绍每个寿司使用的材料，个别师傅还会中文介绍。<br>·这里只有十几个座位，每天凌晨四点就会排起长队，要做好长时间等待的准备。
1017168449	7	4	交通：在筑地站搭乘东京地下铁“日比谷”线至银座站，换乘东京地下铁“有乐町”线至新桥站，最后换乘“海鸥线”抵达台场海滨公园站。
1017168449	7	5	地址：港区台场1-7-1 <br>日本一家网红咖喱蛋包饭店，酱汁都特别浓郁，猪排外脆里嫩，很大一块，而且不会是面粉面包糠这种裹出来的大，日式的蛋包饭的蛋皮很嫩很嫩，而且稍带些湿润的感觉~！
1017168449	7	6	交通：“台场站”下车，步行2分钟抵达。
1017168449	7	7	交通：搭乘海鸥线至“新桥站”，后换乘银座线至“银座站”。
1017168449	7	8	地址：東京都 中央区 銀座 8-7 銀座ナイン2号館 2F<br><br>日本知名连锁餐厅，提供做 法各异、滋味不同的蟹肉大餐，这家分店位于银座，人气非常旺。
1017168449	7	9	东京—国内
1017168449	7	10	您可以在酒店餐厅内享用丰富的自助早餐。
1017168449	7	11	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1017168449	7	12	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1017168449	7	13	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1017168449	7	14	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1017168449	7	15	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1017168449	7	16	乘坐舒适的班机返回国内，结束本次愉快的旅途
1017168449	7	17	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1021931014	1	1	国内—东京
1021931014	2	1	东京
1021931014	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
1021931014	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
1021931014	2	4	步行前往即可～
1021931014	2	5	叙叙苑由创业以来一直坚持为顾客提供高质料理与优质的服务。菜单以「和牛」为中心，食材全由专人严选出来。配上无烟烧肉的设备与优雅的装潢，令您享受到日本美妙的用餐。
1021931014	2	6	交通：从新宿商区可步行至酒店~
1021931014	3	1	东京迪士尼度假区
1021931014	3	2	您可以在酒店餐厅内享用丰富的自助早餐。
1021931014	3	3	新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
1021931014	3	4	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 s
1021931014	3	5	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
1021931014	3	6	浅草寺搭乘银座线到上野站，车程约5分钟。
1021931014	3	7	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼老 字号店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种制作方法，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。
1021931014	3	8	交通：搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
1021931014	4	1	东京
1021931014	4	2	您可以在酒店餐厅内享用丰富的自助早餐。
1021931014	4	3	交通：在新宿站搭乘JR中央线抵达东京站，后换乘JR京叶线至舞滨站~
1021931014	4	4	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
1021931014	4	5	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
1021931014	4	6	交通：在舞滨站搭乘JR京叶线抵达东京站，后换乘JR中央线至新宿站~
1021931014	5	3	地址：东京都东京都中央区筑地6-21-2<br><br>寿司大是筑地市场著 名的两家店之一，与大和寿司齐名。<br>·店内寿司都是现场捏制，吃完一个做一个，很大程度的保证了食材的新鲜。<br>·寿司师傅都超热情，会介绍每个寿司使用的材料，个别师傅还会中文介绍。<br>·这里只有十几个座位，每天凌晨四点就会排起长队，要做好长时间等待的准备。
1021931014	5	4	交通：在筑地站搭乘东京地下铁“日比谷”线至银座站，换乘东京地下铁“有乐町”线至新桥站，最后换乘“海鸥线”抵达台场海滨公园站。
1021931014	5	5	地址：港区台场1-7-1 <br>日本一家网红咖喱蛋包饭店，酱汁都特别浓郁，猪排外脆里嫩，很大一块，而且不会是面粉面包糠这种裹出来的大，日式的蛋包饭的蛋皮很嫩很嫩，而且稍带些湿润的感觉~！
1021931014	5	6	交通：“台场站”下车，步行2分钟抵达。
1021931014	5	7	乘坐東京臨海高速鉄道りんかい線直达惠比寿站，步行10分钟到达
1021931014	5	8	醍醐坐落于日本传统的花岗岩石堆砌而成的四方庭院，庭院当中长松翠柏环绕。可以一边眺望日本美丽的庭园，一边品味着日本料理，置身这别致的空间会让人忘记这里是Tokyo。餐厅根据日本的四季不同，提供每月更换的日式套餐。让你从舌尖体验春季的华丽，夏季的清凉感，秋季的喜悦，美丽冬季的情景。 精心制作正宗的怀石套餐 <br>菜品简介<br>第四代店主继承了代代相传的烹饪基因，精通传承已久的日本料理技艺，又乐于不断地去尝试和挑战，对日本传统料理做出全新的诠释，总能给我们带来惊喜。
1021931014	5	9	交通：搭乘东京地下铁丸之内线至新宿站，后步行抵达酒店。
1021931014	5	10	东京—国内
1021931014	5	11	您可以在酒店餐厅内享用丰富的自助早餐。
1021931014	5	12	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1021931014	5	13	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1021931014	5	14	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1021931014	5	15	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1021931014	5	16	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1021931014	5	17	乘坐舒适的班机返回国内，结束本次愉快的旅途
1021931014	5	18	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1011208034	1	1	国内—东京
1011208034	2	1	东京—箱根（新宿—小田原—汤本）
1011208034	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
1011208034	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>利木津官网：http://www.limousinebus.co.jp/ch1/ <br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
1011208034	2	4	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
1011208034	2	5	交通：从新宿商区可步行至酒店~
1011208034	3	1	箱根—东京
1011208034	3	2	如果预订了含早的房型，可以在酒店享用自助餐，便利店也有很多不错的早餐选择
1011208034	3	3	东京市区至箱根<br>1、小田急浪漫特快车、从新宿出发即可直达箱根小田原站的特快列车，座位舒适、车窗角度更分明，平稳而流畅的行驶过程中，关东地方景致在窗外如卷轴画一般铺展开来。当人们仍迷醉于沿途风光时，仅85分钟小田急浪漫特快车已优雅地抵达箱根小田原站。<br>2、从东京站搭乘新干线至箱根小田原站，后换乘登山电车至箱根汤本车站。如前往强罗，需在汤本车站下车后换乘汤本至强罗登山电车。每小时1~3班。 <br><br>Tips：您可以将大件行李寄存在东京酒店，只需携带部分换洗衣物和必要装备前往。<br>避免在乘坐公共交通时发生托运行李的烦恼~~
1011208034	3	4	JR小田原站可步行抵达，步行时间约10分钟~
1011208034	3	5	地址：日本神奈川県足柄下郡箱根町宮ノ下296<br>交通：搭乘箱根登山铁道至宫丿下站，下车后步行10分钟抵达~<br>午餐营业时间：11:30-13:30<br><br>日本人气电视剧《孤独美食家》中介绍的餐厅，特的牛排饭~值得一试~<br>Tips：抵达后，需要先在门口的纸上写上自己的名字用来排队，等开门后店主会根据姓名的顺序请各位进店用餐~各位请写英文名或者用同音的平假名代替自己的名字，不要写中文哦~同时，如果你想尝尝这个美味，请一定尽早过去排队，限量提供可不是闹着玩哦~
1011208034	3	7	交通：在元箱根港搭乘箱根巴士抵达箱根汤本站，后步行至酒店，步行时间约5分钟。
1011208034	4	1	东京
1011208034	4	2	如果预订了含早的房型，可以在酒店享用自助餐，便利店也有很多不错的早餐选择
1011208034	4	3	汤本车站至御殿场outlets<br>可在汤本巴士站搭乘巴士直达御殿场outlet。<br>注意：巴士时间为每天4班，巴士出发参考时间：08：57；09：10；13：01；13：20。 
1011208034	4	4	御殿场奥特莱斯美食广场中有非常多的当地料理，您可以自由选择。
1011208034	4	5	如天气良好，御殿场奥特莱斯可以远眺富士山全景哦~
1011208034	4	6	交通：1、可搭乘箱根巴士返回箱根汤本站，后搭乘小田急浪漫号直达东京新宿站。<br>2、可在御殿场奥特莱斯搭乘高速巴士抵达东京站。
1011208034	4	7	交通：搭乘JR山手线抵达涩谷站。
1011208034	4	8	地址：东京都涩谷区樱丘町28-2三笠大楼 <br><br>高太郎是主打创意料理的居酒屋，装修非常精致，常年人气十足。主厨以日本各地精选的食材来打造创意料理，酒单非常有特色，令人有耳目一新的感觉。 
1011208034	4	9	搭乘东京东横线至涩谷站，后换乘JR山手线至新宿站。 
1011208034	5	1	东京—国内
1011208034	5	2	如果预订了含早的房型，可以在酒店享用自助餐，便利店也有很多不错的早餐选择
1011208034	5	3	搭乘新宿线至九段站下车~
1011208034	5	4	您可围绕皇居，漫漫步行~~
1011208034	5	5	地址：東京都中央区銀座4-6-18，銀座アクトビル4階<br><br>寿司清是一家1889年在筑地创业的百年老店，店不大，日式风格，大家都会围坐在吧台一样的桌子旁，厨师在其中制作寿司，拿捏寿司的姿势很标准，做完的寿司会一道道摆在你面前。鱼切得不薄不厚，能够的盖在醋饭上，入口刚刚好，食材无可挑剔，留在嘴里的只有鲜甜的滋味。午餐相对便宜一点，总体价位都很实惠。
1011208034	5	6	皇居可步行至银座商业街~
1011208034	5	7	地址：東京都 中央区 銀座 8-7 銀座ナイン2号館 2F<br><br>日本知名连锁餐厅，提供各异、滋味不同的蟹肉大餐，这家分店位于银座，人气非常旺。
1011208034	5	8	交通：搭乘东京地下铁丸之内线至新宿站，后步行抵达酒店。
1011208034	5	9	东京—国内
1011208034	5	10	您可以在酒店餐厅内享用丰富的自助早餐。
1011208034	5	11	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1011208034	5	12	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1011208034	5	13	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1011208034	5	14	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1011208034	5	15	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1011208034	5	16	乘坐舒适的班机返回国内，结束本次愉快的旅途
1011208034	5	17	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024942188	1	1	国内—东京—轻井泽
1024942188	2	1	轻井泽滑雪
1024942188	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。<br>您可以选择机场利木津巴士或者JR express抵达新宿
1024942188	2	3	从东京上野站乘坐北陆新干线到达轻井泽站，车程约1.5小时。<br>可以访问东日本旅客铁路公司（JR-East)官网知晓更多信息
1024942188	3	1	轻井泽—东京
1024942188	3	2	请至酒店内餐厅享用自助早餐<br>
1024942188	3	3	从JR轻井泽车站到接驳巴士站的路线，王子饭店官网有详细的说明，乘坐免费穿梭巴士大约需要10分钟。<br><br>7:30 A.M.～9:00 P.M. 每隔30分钟运行一次。从车站南口到停车站徒步3分钟。
1024942188	3	4	滑雪场拥有维护良好的滑道，主要适合初中级滑雪者，另外还有几个雪上乐园。滑雪场的山脚下是庞大的休闲度假区，拥有数家王子大饭店和一家大型购物中心，中途可以在这里享用午餐哦～<br><br>雪场还提供滑雪课程：<br>【冈部哲也滑雪学校】、【轻井泽滑雪学校】、【轻井泽熊猫人儿童滑雪学校】
1024942188	3	5	可在酒店内享用晚餐
1024942188	4	1	东京（筑地市场+台场+银座）
1024942188	4	2	请至酒店内餐厅享用自助早餐<br>
1024942188	4	3	有了昨日的学习，请尽情享受在雪地飞翔的乐趣～！
1024942188	4	4	开开心心来滑雪，欢欢喜喜去购物！轻井泽不仅可以享受滑雪的乐趣，还可以满足你的购物欲！<br>购物、美食广场、餐厅营业时间：上午10点-下午7点
1024942188	4	5	乘坐北陆新干线从轻井泽站到达东京站，车程约1.5小时。
1014187071	2	4	就在黑门市场里边逛街边吃小吃，吃到饱吧
1014187071	2	5	自黑门市场步行7分钟即可到达大阪瑞士南海酒店
1014187071	3	1	大阪—京都
1024942188	4	6	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。
1024942188	5	1	可选购富士山+河口湖一日游
1024942188	5	2	交通：在新宿站搭乘东京地下铁“丸之内”线至银座站，后换乘东京地下铁“日比谷”线至筑地站下车。后步行抵达。
1024942188	5	3	地址：东京都东京都中央区筑地6-21-2<br><br>寿司大是筑地市场很的两家店之一，与大和寿司齐名。<br>·店内寿司都是现场捏制，吃完一个做一个，很大程度的保证了食材的新鲜。<br>·寿司师傅都超热情，会介绍每个寿司使用的材料，个别师傅还会中文介绍。<br>·这里只有十几个座位，每天凌晨四点就会排起长队，要做好长时间等待的准备。
1024942188	5	4	交通：在筑地站搭乘东京地下铁“日比谷”线至银座站，换乘东京地下铁“有乐町”线至新桥站，最后换乘“海鸥线”抵达台场海滨公园站。
1024942188	5	5	地址：港区台场1-7-1 <br>日本一家网红咖喱蛋包饭店，酱汁都特别浓郁，猪排外脆里嫩，很大一块，而且不会是面粉面包糠这种裹出来的大，日式的蛋包饭的蛋皮很嫩很嫩，而且稍带些湿润的感觉~！
1024942188	5	6	交通：“台场站”下车，步行2分钟抵达。
1024942188	5	7	交通：搭乘海鸥线至“新桥站”，后换乘银座线至“银座站”。
1024942188	5	8	地址：東京都 中央区 銀座 8-7 銀座ナイン2号館 2F<br><br>日本知名连锁餐厅，提供制作方法各异、滋味不同的蟹肉大餐，这家分店位于银座，人气非常旺。
1024942188	5	9	交通：搭乘东京地下铁丸之内线至新宿站，后步行抵达酒店。
1024942188	6	1	东京--国内
1024942188	6	2	可以享用酒店内的自助早餐，或者在便利店购买
1024942188	6	3	新宿西口（平成观光候车室）<br>地址：東京都新宿区西新宿１－２１－１１　山銀ビル（bill)４F <br>集合时间：08:15
1024942188	6	4	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。
1024942188	6	5	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>搭乘旅游巴士返回东京新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
1024942188	6	6	交通：从新宿商圈可步行返回酒店。
1024942188	6	7	东京--国内
1024942188	6	8	您可以在酒店餐厅内享用丰富的自助早餐。
1024942188	6	9	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1024942188	6	10	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1024942188	6	11	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1024942188	6	12	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1024942188	6	13	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1024942188	6	14	乘坐舒适的班机返回国内，结束本次愉快的旅途
1024942188	6	15	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1014187071	1	1	感受大阪市井风情
1014187071	2	1	大阪经典景点一日游
1014187071	2	2	抵达关西机场后，您可以选用以下方式前往大阪市内入住酒店。从关西机场到大阪区，比较常用的有4种到达方法。<br> ——————————<br> （1）ＨＡＲＵＫＡ特急<br> （2）南海电车<br> （3）JR关西机场线关空快速<br> （4）关西机场交通车，也就是巴士<br><br>南海电铁可以直达难波站，推荐乘坐Lapid特急车型。入住大阪瑞士南海酒店的客人到达后可直接在站内进入酒店<br>希望到梅田的客人，乘坐JR HARUKA到天王寺转地铁御堂筋线到梅田或者南海电铁到难波站转地铁御堂筋线到梅田。
1014187071	2	3	入住酒店后，如果时间允许您可以就近逛逛。在这里小编推荐给您黑门市场。黑门市场在难波地区，步行即可到达<br>营业时间：9：00-18：00，部分营业到19：00，20：00<br>经营内容：<br>海鲜，小吃，寿司，火锅，日本特产，等等。重要的是又便宜又好吃啊。<br>优点：能买到很多物美价廉的水果，小吃，还能买到手信。内容丰富，适合逛很长时间。
1014187071	3	2	在酒店享用早餐后，在难波站上车，乘坐御堂筋线心斋桥站换乘長堀鶴見緑地線至森之宫站下车出站。步行约400米至大阪城公园。
1014187071	3	3	大阪城最初是日本关白丰臣秀吉所建居城，历经战火摧残，在近代重建。现在的大阪城公园是参考丰臣和德川时代的大阪城特征重建的，内中是大阪城历史展览。大阪城是大阪的象征，也是大阪一处有名的休闲胜地。
1014187071	3	4	在大阪城公园根据路标指示前往搭乘大阪水上巴士大阪城站， 搭乘水上巴士。水上巴士主要的是穿梭在包括大阪城港在内的4个观光景点间的“阿库阿号”，行船航线为大阪城港-天满桥港-淀屋桥港-OAP港，下船后可直接在OAP商业区解决午餐
1014187071	3	5	心斋桥是大阪的商业街区，既有种类齐全的百货商店，也有实惠的路边小店，您可在此尽情游逛，海淘心头之好。逛累了，还可以走向道顿崛方向品尝美食。
1014187071	3	6	大阪南海瑞士酒店--搭乘地铁御堂筋线返回难波站出站即到
1014187071	3	7	自OAP港步行750米至樱之宫，使用JR PASS乘坐JR大阪环状线到达大阪（梅田）站，换乘地下铁御堂筋线前往心斋桥站
1014187071	3	8	晚餐在道顿崛尽情品尝大阪有名的螃蟹道乐、章鱼丸子、大阪烧、金龙拉面等美食。
1014187071	4	1	嵯峨野观光小火车--保津川漂流--岚山--入住京都
1014187071	4	2	从大阪站可以乘坐JR京都线(又名“东海道本线”)前往京都站，列车分为新快速、快速、普通三种，单程票价560円，新快速列车车程只需约30分钟，快速列车约45分钟，普通列车约1小时。
1014187071	4	3	交通：酒店提供京都站至酒店免费接驳巴士~
1014187071	4	4	JR京都站至清水寺：<br>巴士广场搭乘市营100京都駅前行，经5站，清水道站下车。
1014187071	4	5	交通：清水寺可步行至三年坂二年坂。
1014187071	4	6	门口有藤原纪香姐姐坐着很好认，里面还有几个美女姐姐坐桌边可以陪吃~ 这家店牛的是全店只卖一种食物--特定材料的お好み焼き，680日元一份，只要跟店员说要几份就可以了。味道真心很赞！
1014187071	4	7	交通：可步行抵达，步行时间约10分钟
1014187071	4	8	交通：可步行抵达~
1014187071	4	9	地址：京都府京都市下京区烏丸通塩小路下ル東塩小路町901京都駅ビル 10F<br>交通：搭乘市営100或市営206抵达京都站<br><br>京都JR车站内的拉面小路在游客一族中知名度非常高，究其原因是其地理位置非常方便好找，价格实惠而且选择众多。拉面小路云集了日本各地有名的拉面店，从浓厚的九州博多拉面，到纯正的札幌味增拉面，都能在这里吃到。如果好奇京都人本地口味的，可以选择老铺すまたに，来一碗叉烧面。
1014187071	5	1	京都—东京
1014187071	5	2	乘坐地铁或免费接送车至京都站，转乘JR嵯峨野线（又名为JR山阴本线）。京都站到嵯峨–岚山站的单趟车程为15分钟，票价为230日元。在JR嵯峨站下车出站后，在车站旁就能买到嵯峨小火车车票，票价620日元。
1014187071	5	3	从乘坐小火车沿山西行，到终点站龟冈站下车后搭乘渡口巴士，大概15分钟可以到渡。在渡口购买保津川漂流出船票。游船营业时间上午9点到下午2-3点，价格3900日元。
1014187071	5	4	抵达岚山后，在岚山古街用餐。推荐小仓山京都汤豆腐料理。
1014187071	5	5	【嵯峨野观光小火车：赏沿途美枫】<br>嵯峨野观光小火车铺着木头地板，吊灯做成煤气灯的样子，造型复古。小火车行驶在Torokko嵯峨站（JR嵯峨岚山站旁）和Torokko龟冈站之间，沿保津峡上的铁道前行，一路有淙淙河水相伴，春天的樱花、秋天的红枫令人沉醉，保津峡站、龟冈站的一整排狸猫塑像憨态可掬，在风景好的地方，小火车甚至会停下让游客尽情拍照。
1014187071	5	6	【保津川漂流：如在画中行】<br>木船上有船工划船，乘船顺保津川而下，两岸葱郁的树木吐出清新的空气，奇礁怪石接踵而至，还有机会看到行驶中的嵯峨野观光小火车，与小火车打招呼是漂流的“传统节目”。漂流中虽然也有湍急的段落，但多数段落还算平稳，老人和孩子也可以尝试乘坐。
1014187071	5	7	在欣赏了一日的岚山美景后，可以回到京都市区品尝一顿地道的京都怀石料理。推荐山荘京大和 サンソウキョウヤマト店，在京都站下车，市营巴士206路东山通北大路终点站方向约20分、東山安井下车、徒步5分钟到。
1014187071	5	8	京都威斯汀大酒店。
1014187071	5	9	山荘京大和 サンソウキョウヤマト怀石料理店。<br>环境：个人古典空间里，悠闲的享用道地“京都怀石”精致美味料理。<br>食物：京都老饭店以四季时节食材为主，将来自世界各地的新鲜食材，融入纯正日本传统手法，精心烹煮出传统老饭店独特风味，京都怀石料理佳肴，值得您细细品味。
1014187071	6	1	东京（浅草—东京晴空塔—上野公园）
1014187071	6	2	在酒店享用早餐后，办理酒店退房手续后，搭乘酒店的接驳巴士前往京都站。<br>在京都站搭乘东海道新干线。这是快的交通方式。分为三种车型：希望号Nozomi、光速号Hikar和回音号Kodama，是根据速度不同而区分的，从京都到东京的时间分别是140分钟、160分钟和4小时。希望号单程票价约13500日元。
1014187071	6	3	交通：搭乘JR中央线至新宿站下车。新宿商区可步行抵达酒店~办理入住手续
1014187071	6	4	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下
1014187071	6	5	午餐后前往周边游览
1014187071	6	6	步行即可到达，继续游览。
1021086987	7	3	交通：在筑地站搭乘东京地下铁“日比谷”线至银座站，换乘东京地下铁“有乐町”线至新桥站，最后换乘“海鸥线”抵达台场海滨公园站。
1014187071	6	7	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
1014187071	6	8	晚餐后可在周边逛一逛，然后回酒店休息。
1014187071	7	1	东京
1014187071	7	2	在酒店享用早餐后，从新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
1014187071	7	3	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
1014187071	7	4	浅草寺搭乘银座线到上野站，车程约5分钟。
1014187071	7	5	搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
1014187071	7	6	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 
1014187071	7	7	s
1014187071	7	8	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。 
1014187071	8	1	东京—国内
1014187071	8	2	交通：在新宿站搭乘东京地下铁“丸之内”线至银座站，后换乘东京地下铁“日比谷”线至筑地站下车。后步行抵达。
1014187071	8	3	交通：在筑地站搭乘东京地下铁“日比谷”线至银座站，换乘东京地下铁“有乐町”线至新桥站，最后换乘“海鸥线”抵达台场海滨公园站。
1014187071	8	4	地址：东京都东京都中央区筑地6-21-2<br><br>寿司大是筑地市场的两家店之一，与大和寿司齐名。<br>·店内寿司都是现场捏制，吃完一个做一个，大程度的保证了食材的新鲜。<br>·寿司师傅都超热情，会介绍每个寿司使用的材料，个别师傅还会中文介绍。<br>·这里只有十几个座位，每天凌晨四点就会排起长队，要做好长时间等待的准备。
1014187071	8	5	地址：港区台场1-7-1 <br>日本一家网红咖喱蛋包饭店，酱汁都特别浓郁，猪排外脆里嫩，很大一块，而且不会是面粉面包糠这种裹出来的大，日式的蛋包饭的蛋皮很嫩很嫩，而且稍带些湿润的感觉~！
1014187071	8	6	交通：“台场站”下车，步行2分钟抵达。
1014187071	8	7	交通：搭乘电车百合海鸥号至青海站下车，步行约3分钟即到。或可直接步行抵达。
1014187071	8	8	地址：東京都 中央区 銀座 8-7 銀座ナイン2号館 2F<br><br>日本知名连锁餐厅，提供各异、滋味不同的蟹肉大餐，这家分店位于银座，人气非常旺。
1014187071	8	9	交通：搭乘东京地下铁丸之内线至新宿站，后步行抵达酒店。
1014187071	8	10	交通：搭乘海鸥线至“新桥站”，后换乘银座线至“银座站”。
1014187071	8	11	东京—国内
1014187071	8	12	您可以在酒店餐厅内享用丰富的自助早餐。
1014187071	8	13	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1014187071	8	14	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1014187071	8	15	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1014187071	8	16	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1014187071	8	17	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1014187071	8	18	乘坐舒适的班机返回国内，结束本次愉快的旅途
1014187071	8	19	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1021086987	1	1	感受大阪市井风情
1021086987	2	1	大阪经典景点一日游
1021086987	2	2	自黑门市场步行7分钟即可到达大阪瑞士南海酒店
1021086987	2	3	就在黑门市场里边逛街边吃小吃，吃到饱吧
1021086987	2	4	入住酒店后，如果时间允许您可以就近逛逛。在这里小编推荐给您黑门市场。黑门市场在难波地区，步行即可到达<br>营业时间：9：00-18：00，部分营业到19：00，20：00<br>经营内容：<br>海鲜，小吃，寿司，火锅，日本特产，等等。重要的是又便宜又好吃啊。<br>优点：能买到很多物美价廉的水果，小吃，还能买到手信。内容丰富，适合逛很长时间。
1021086987	2	5	抵达关西机场后，您可以选用以下方式前往大阪市内入住酒店。从关西机场到大阪区，比较常用的有4种到达方法。<br> ——————————<br> （1）ＨＡＲＵＫＡ特急<br> （2）南海电车<br> （3）JR关西机场线关空快速<br> （4）关西机场交通车，也就是巴士<br><br>南海电铁可以直达难波站，推荐乘坐Lapid特急车型。入住大阪瑞士南海酒店的客人到达后可直接在站内进入酒店<br>希望到梅田的客人，乘坐JR HARUKA到天王寺转地铁御堂筋线到梅田或者南海电铁到难波站转地铁御堂筋线到梅田。
1021086987	3	1	大阪-伏见稻荷大社--清水寺、三年坂二年坂--八坂神社、花见小路--返回大阪
1021086987	3	2	晚餐在道顿崛尽情品尝大阪有名的螃蟹道乐、章鱼丸子、大阪烧、金龙拉面等美食。
1021086987	3	3	自OAP港步行750米至樱之宫，使用JR PASS乘坐JR大阪环状线到达大阪（梅田）站，换乘地下铁御堂筋线前往心斋桥站
1021086987	3	4	大阪南海瑞士酒店--搭乘地铁御堂筋线返回难波站出站即到
1021086987	3	5	心斋桥是大阪的商业街区，既有种类齐全的百货商店，也有实惠的路边小店，您可在此尽情游逛，海淘心头之好。逛累了，还可以走向道顿崛方向品尝美食。
1021086987	3	6	在大阪城公园根据路标指示前往搭乘大阪水上巴士大阪城站， 搭乘水上巴士。水上巴士主要的是穿梭在包括大阪城港在内的4个观光景点间的“阿库阿号”，行船航线为大阪城港-天满桥港-淀屋桥港-OAP港，下船后可直接在OAP商业区解决午餐
1021086987	3	7	大阪城最初是日本关白丰臣秀吉所建居城，历经战火摧残，在近代重建。现在的大阪城公园是参考丰臣和德川时代的大阪城特征重建的，内中是大阪城历史展览。大阪城是大阪的象征，也是大阪一处有名的休闲胜地。
1021086987	3	8	在酒店享用早餐后，在难波站上车，乘坐御堂筋线心斋桥站换乘長堀鶴見緑地線至森之宫站下车出站。步行约400米至大阪城公园。
1021086987	4	1	大阪—东京
1021086987	4	2	您可以在酒店附近找一家拉面店，品尝正宗的关西拉面。
1021086987	4	3	从京都站搭乘阪急线到清水五条站下车，步行约10分钟到清水寺。
1021086987	4	4	享用一顿丰盛的早餐后，步行到难波站，搭乘御堂筋线到梅田站，然后换乘JR前往京都站，大约需要1小时30分钟左右。
1021086987	4	5	逛完清水寺后可以顺道去三年坂二年坂游玩。
1021086987	4	6	寻一家路边小店品尝地道料理，看着墙上斑驳的光影，体验古都千年历史，恍若隔世。
1021086987	4	7	餐后慢慢步行至祗园，兴致高的话可以进行和服换装，漫步在祗园老街，感受古都风情。也可以顺路去八坂神社，花见小路漫步。
1021086987	4	8	返回京都站坐JR到大阪。乘坐JR到大阪至梅田站换乘地铁御堂筋线至难波（なんば）站下车抵达南海瑞士酒店。
1021086987	5	1	东京（浅草—东京晴空塔—上野公园）
1021086987	5	2	在酒店享用早餐后，搭乘JR前往新大阪站，在新大阪站搭乘东海道新干线直达东京站，新干线时间大约需要2小时30分钟。
1021086987	5	3	交通：搭乘JR中央线至新宿站下车。新宿商区可步行抵达酒店~办理入住手续<br><br>如您未到酒店checkin时间，可先将行李寄存在前台。
1021086987	5	4	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下
1021086987	5	5	午餐后前往周边游览
1021086987	5	6	步行即可到达，继续游览。
1021086987	5	7	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
1021086987	5	8	晚餐后可在周边逛一逛，然后回酒店休息。
1021086987	6	1	东京
1021086987	6	2	在酒店享用早餐后，从新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
1021086987	6	3	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。
1021086987	6	4	浅草寺搭乘银座线到上野站，车程约5分钟。
1021086987	6	5	搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~
1021086987	6	6	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。 
1021086987	6	7	s
1021086987	6	8	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。 
1021086987	7	1	东京迪士尼度假区
1021086987	7	2	交通：在新宿站搭乘东京地下铁“丸之内”线至银座站，后换乘东京地下铁“日比谷”线至筑地站下车。后步行抵达。
1021086987	7	4	地址：东京都东京都中央区筑地6-21-2<br><br>寿司大是筑地市场的两家店之一，与大和寿司齐名。<br>·店内寿司都是现场捏制，吃完一个做一个，大程度的保证了食材的新鲜。<br>·寿司师傅都超热情，会介绍每个寿司使用的材料，个别师傅还会中文介绍。<br>·这里只有十几个座位，每天凌晨四点就会排起长队，要做好长时间等待的准备。
1021086987	7	5	地址：港区台场1-7-1 <br>日本一家网红咖喱蛋包饭店，酱汁都特别浓郁，猪排外脆里嫩，很大一块，而且不会是面粉面包糠这种裹出来的大，日式的蛋包饭的蛋皮很嫩很嫩，而且稍带些湿润的感觉~！
1021086987	7	6	交通：“台场站”下车，步行2分钟抵达。
1021086987	7	7	交通：搭乘电车百合海鸥号至青海站下车，步行约3分钟即到。或可直接步行抵达。
1021086987	7	8	地址：東京都 中央区 銀座 8-7 銀座ナイン2号館 2F<br><br>日本知名连锁餐厅，提供各异、滋味不同的蟹肉大餐，这家分店位于银座，人气非常旺。
1021086987	7	9	交通：搭乘东京地下铁丸之内线至新宿站，后步行抵达酒店。
1021086987	7	10	交通：搭乘海鸥线至“新桥站”，后换乘银座线至“银座站”。
1021086987	8	1	东京—国内
1021086987	8	2	交通：在新宿站搭乘JR中央线抵达东京站，后换乘JR京叶线至舞滨站~
1021086987	8	3	交通：在舞滨站搭乘JR京叶线抵达东京站，后换乘JR中央线至新宿站~
1021086987	8	4	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
1021086987	8	5	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
1021086987	8	6	您可以在酒店餐厅内享用丰富的自助早餐。
1021086987	8	7	东京—国内
1021086987	8	8	您可以在酒店餐厅内享用丰富的自助早餐。
1021086987	8	9	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1021086987	8	10	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1021086987	8	11	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1021086987	8	12	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1021086987	8	13	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1021086987	8	14	乘坐舒适的班机返回国内，结束本次愉快的旅途
1021086987	8	15	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1014539361	1	1	国内—东京
1014539361	2	1	东京—河口湖
1014539361	2	2	乘坐舒适的国际航班，从国内抵达日本国内第一大城市——东京都。
1014539361	2	3	您可以选择机场利木津巴士或者JR express抵达新宿<br>如您选择较早航班抵达，您可先把行李寄存在酒店，然后去附近商圈逛逛，体验东京这座城市的魅力！
1014539361	2	4	步行前往即可～
1014539361	2	5	地址:東京都新宿区新宿3-34-11 ピースビルB1F<br><br>起源于九州，是博多拉面的一种，也是当地豚骨白汤拉面的代表，蔡澜强力推荐的一家拉面店，在店里可以经常撞见明星哦。这里拥有“一个人也可以吃拉面”和“专心吃面”的拉面文化，与众不同的小隔间设计，你在帘子这头吃面，厨师在另一头制作拉面，私密性很好，单身人士就餐的福地。 备有各种语言的菜单，上面分类详细到拉面的份量、软硬程度、汤底浓度等等，十分贴心。每个人的桌子上有杯子，可以自助接水。这里的拉面汤头浓郁，面身筋道，吃完拉面一定要大口喝掉汤，碗底会有惊喜哦。除了地道的博多拉面外，温泉蛋、限定豆腐甜品不妨也尝试一下喽。 
1014539361	2	6	交通：从新宿商区可步行至酒店~
1014539361	3	1	河口湖
1014539361	3	2	您可以在酒店餐厅内享用丰富的自助早餐。
1014539361	3	3	交通方式：<br>1、搭乘JR中央线至大月站，换乘私营富士急线电铁抵达河口湖站。<br>2、新宿西口搭乘富士急巴士抵达河口湖站。
1014539361	3	4	交通：从河口湖站可步行抵达景点。
1014539361	3	5	来到河口湖边，如果天气晴朗，您可远眺富士山全景。
1014539361	3	6	地址：山梨県南都留郡富士河口湖町船津4120-1<br><br>Tabelog排名第 一的炸物店（河口湖），怎么能错过。<br>餐厅装修朴实的风格，一面操作台，一个炸锅，一个女生，组成了整个炸物店。<br>菜单是极简风格，店里只卖五种炸物，从简单的炸土豆饼，到精贵的炸猪排，真的是很有极客精神，就把五种炸物做到JI致。<br>s
1014539361	3	7	交通：可步行抵达。
1014539361	3	8	交通：可步行抵达。
1014539361	3	9	交通：可步行抵达。<br><br>推荐玩法：公园内可搭乘缆车上山，俯瞰整个河口湖的景色，这里也是观赏富士山的一个绝 佳场所。
1014539361	3	10	您可以在温泉旅馆享用一次丰盛的怀石料理。
1014539361	3	11	交通：酒店提供免费接驳巴士（河口湖车站—酒店）。
1014539361	4	1	河口湖—东京
1014539361	4	2	您可以在酒店餐厅内享用丰富的自助早餐。
1014539361	4	3	交通方式：在河口湖站搭乘富士急行巴士抵达。
1014539361	4	4	您可以在富士急乐园内挑选一家心仪餐厅进行用餐。
1014539361	4	5	交通：搭乘富士急行巴士抵达河口湖站。<br>您可以漫步河口湖，欣赏这里每一寸风景。
1014539361	4	6	交通：酒店提供免费接驳巴士（河口湖车站—酒店）。
1014539361	5	1	东京（浅草—东京晴空塔—上野公园）
1014539361	5	2	您可以在酒店餐厅内享用丰富的自助早餐。
1014539361	5	3	交通方式：<br>搭乘私营富士急线电铁抵达大月站，后换乘JR中央线至新宿站。<br>
1014539361	5	4	交通：搭乘JR山手线抵达涩谷站。
1014539361	5	5	地址：东京都涩谷区樱丘町28-2三笠大楼 <br><br>高太郎是主打创意料理的居酒屋，装修非常精致，常年人气十足。主厨以日本各地精选的食材来打造创意料理，酒单非常有特色，令人有耳目一新的感觉。
1014539361	5	6	交通：可步行抵达表参道。
1014539361	5	7	交通：可步行抵达。
1014539361	5	8	地址：东京都新宿区新宿3-17-13 雀の伯父さんビル 1F<br>交通：搭乘JR山手线至新宿，后步行抵达。<br><br>东京很常见的一家海鲜烧烤连锁店，也有各种寿司和鱼生。招牌菜是用味噌烤螃蟹和各种贝壳类烧烤。24小时营业的店面非常热闹，是个适合朋友聚会，是个气氛轻松，可以大口喝酒开怀吃海鲜的地方。
1014539361	5	9	交通：可步行抵达。
1014539361	6	1	东京迪士尼度假区
1014539361	6	2	您可以在酒店餐厅内享用丰富的自助早餐。
1014539361	6	3	新宿至浅草寺，车程约36分钟，换乘方法：<br>1、先乘坐丸之内线·池袋行至赤坂见附；<br>2、换乘银座线·浅草行至浅草站。 
1014539361	6	4	地址:东京都台东区浅草2-2-5<br><br>明治28年开创的老铺，就位于浅草寺的附近，整个餐馆的风格也遗传了浓厚的传统氛围，清净的中庭、有着日本艺术气息的屋子、满是传统文化的雕刻，塑造了绝 佳的就餐环境。一楼专营适合作为礼品的牛肉等，二楼、三楼为饮食区，有大包间。入口即化的上等牛肉可是这里的特色哦，将它与白菜、大葱、豆腐等一起入锅烤，美味满分，所有的步骤可以由服务员来完成，初次光临的顾客也能放心用餐。如果有消费能力的话，可以尝试下菜单上的菜品。
1014539361	6	5	您可以漫漫步行至东京晴空塔，或搭乘浅草线至押上站抵达。 
1014539361	6	6	浅草寺搭乘银座线到上野站，车程约5分钟。 
1014539361	6	7	地址：东京都台东区上野2-12-22<br><br>位于上野公园不忍池对面的已有260年历史的鳗鱼老 字号店铺了。店堂装修考究，处处透漏着用心的痕迹。 他们家的鳗鱼有两种制作方法，蒲烧和白烧，蒲烧就是边烧鳗鱼边抹点特制甜酱汁，白烧则是放一点点盐花，不涂酱汁，烧出来的比较原味清淡。蒲烧鳗鱼饭很受欢迎，肉嫩味鲜，入口即化哦。服务员竟然是身着和服的奶奶，优雅亲切，殷勤有礼。吃一口肥美的鳗鱼于口中，品尝的不只是美味，还有点滴的历史。
1014539361	6	8	搭乘JR山手线至新宿站，车程约30分钟，后步行至酒店~ 
1014539361	7	1	东京—町田-东京
1014539361	7	2	交通：在新宿站搭乘JR中央线抵达东京站，后换乘JR京叶线至舞滨站~
1014539361	7	3	您可以在酒店餐厅内享用丰富的自助早餐。
1014539361	7	4	优先入座、能和迪士尼明星见面、供应儿童餐、供应低敏餐<br>[菜单]<br>早餐、自助餐、迪士尼明星造型<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>2,000日元-5,000日元
1014539361	7	5	优先入座、供应儿童餐、供应低敏餐<br>[菜单]<br>精致套餐／套餐、牛排、酒精饮料<br>[午餐]<br>2,000日元-5,000日元<br>[晚餐]<br>5,000日元以上
1014539361	7	6	交通：在舞滨站搭乘JR京叶线抵达东京站，后换乘JR中央线至新宿站~
1014539361	8	1	东京—国内
1014539361	8	2	原路返回东京市区
1014539361	8	3	在酒店享受自助餐
1014539361	8	4	从新宿站搭乘浪漫特快江之岛直达町田市，耗时40分钟左右
1014539361	8	5	东京—国内
1014539361	8	6	您可以在酒店餐厅内享用丰富的自助早餐。
1014539361	8	7	若您搭乘的是早航班，请留意您的航班时刻，提前出发前往机场，以免耽误您的行程。<br>若您搭乘的是晚航班，您可将行李寄存在酒店，安排好时间去周边景点游玩或者商场shopping。<br>
1014539361	8	8	若时间还早，可以在新宿度过本次行程的最后一些时间，享用美食，购物逛街都是不错的选择。
1014539361	8	9	地址： 東京都新宿区新宿3-22-7指田ビルB1F<br>电话： +81-3-33547311<br><br>主营炸牛排，它的外皮被炸得酥酥脆脆的，腌料的酱汁味道也处理的相当入味。<br>炸过的牛肉锁住了牛的肉汁和鲜甜，再烤一下就把整个牛肉味道逼出来，<br>整个肉质的软嫩都被完整保留住，精华的肉汁和精华也都完好如初，牛肉香气真的扑鼻而来，不管是直接单吃、沾酱料吃、或是配的白饭吃，都超级好吃。
1014539361	8	10	成田机场<br>可以乘坐利木津巴士或者乘坐成田特快直达成田机场。<br><br>羽田机场<br>可以乘坐利木津巴士或者在新宿站乘坐JR山手线到品川，换乘京急线到达羽田机场。
1014539361	8	11	在第1候机楼的「narita nakamise」、「NARITA NORTH STREET」, 第2候机楼的「NARITA 5号街」, 以及第3候机楼免税店区域，办完登机手续后，这里有大约100多家免税店和TAX-FREE SHOP等候着您的光临。您可在此尽情享受购物乐趣！除了【化妆品·香水】和【酒类·香烟】，还有日本的家用电器、时装杂货、玩具、传统工艺品等，您都能享受到只有在免税店才能提供的超 值购物。在此，您还可以购买到免税店限量版产品以及日本先行销售的新产品等，具有附加值的优质产品可谓数不胜数！另外，一货难求的名酒、人气地方限定版点心也可在此购买到。就连忘记买了的土特产，也可以在成田机场买到哟！<br>
1014539361	8	12	乘坐舒适的班机返回国内，结束本次愉快的旅途
1014539361	8	13	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
3422942	1	1	抵达丽江
3422942	2	1	网红景点打卡——玉龙雪山
3422942	2	2	乘坐自选航班抵达丽江。<br>从三义机场—丽江古城有以下几种方式：<br>1.下单时选择携程接机服务，便捷出行；<br>2.公交：27路公交，在机场路口站上车，昭庆市场站下车，再步行100米即可抵达；<br>3.打出租车：全程约30公里，时常约30分钟
3422942	2	3	如果抵达的早，放好行李，当然要先去心驰神往的丽江古城。酒店就在古城内，让我们即刻开启这段美好的旅途吧。<br>丽江古城城中至今依然大片保持明清建筑特色，“三坊一照壁，四合五天井，走马转角楼”式的瓦屋楼房鳞次栉比，被中外建筑专家誉为“民居博物馆”。古城居民素来喜爱种植花木培植盆景，使古城享有“丽郡从来喜植树，山城无处不飞花”的美誉。
3422942	2	4	【小吃】鸡豆凉粉、纳西烤鱼、粑粑、东巴烤肉是受欢迎的小吃，<br>【火锅】则以腊排骨火锅、洋芋鸡火锅、黑山羊火锅、菌类火锅、牦牛肉火锅为代表。
3422942	3	1	经典体验——拉市海骑马
3422942	3	2	今天建议您前往【玉龙雪山】，这是丽江比较值得看的景点之一，也是纳西族心中的神山，一共13座山峰连绵起伏，似银龙飞舞，因此得名。景区内可以直接乘座索道上山，轻松欣赏高海拔冰川的瑰丽，是很多游客来此游玩的亮点。丽江古城-玉龙雪山约20公里，游玩需要一天时间。<br><br>如何前往：<br>玉龙雪山景区距离酒店较远，丽江公共交通不够发达，建议您报名我们推荐的一日游体验，方便快捷。
3422942	3	3	建议前往玉龙雪山。
3422942	3	4	本地的虹鳟鱼，肉质坚实、小刺少、味道鲜美，是丽江的珍奇佳肴，并非我们所熟悉的海产三文鱼，而是生长在玉龙雪山冰川融水之中，以小鱼小虾为食的高原淡水三文鱼。“一鱼三吃”是常见的美食，即三文鱼刺身，头尾连骨肉下火锅，鱼皮干炸下酒。
3422942	4	1	丽江—大理
3422942	4	2	拉市海位于丽江城西10公里，是一片水草丰美的湿地，湖畔青草依依，水中鱼虾成群，环境优美。这里还是很多候鸟的越冬栖息地，每年都会有十几万只候鸟过冬。拉市海因此也成为丽江骑马、观鸟的好去处，被称为“丽江的马尔代夫”。<br><br>如何前往：<br>拉市海景区距离酒店较远，丽江公共交通不够发达，建议您报名我们推荐的一日游体验，方便快捷。
3422942	4	3	招牌纳西烤肉、梅子酒、什锦山野菜都是推荐您品尝的菜品
3422942	5	1	畅游洱海
3422942	5	2	今天从丽江出发，前往“下关风，上关花，苍山雪，洱海月”的大理，夜宿海边，感受一场与众不同的“春暖花开，面朝大海”的惬意悠然。<br>如何前往：<br>1.购买丽江-大理火车票，耗时2小时以上；<br>2.自行前往丽江客运站，购买丽江——大理的汽车票，票价74元，行驶时常约为3.5小时。
3422942	5	3	刚刚抵达大理，建议您在大理古城逛一逛。<br>平日步履匆匆的你，走进大理，会爱上这里的简约和宁静。<br>我们推荐的酒店就在古城口附近，步行不到5分钟即可抵达大理古城。
3422942	5	4	大理酸辣鱼<br>大理白族待客做的一道菜，酸、微甜、辣构成的奇妙的味觉体验；<br>先是爆香花椒，放姜片、蒜瓣，鲫鱼两面都煎过以后，倒入料酒煮上一会儿，再放入酸木瓜、豆腐，炖煮入味；<br>酸木瓜酸中带有微甜，夹着一股果香味，鲫鱼肉质鲜美，而豆腐吸收了鱼味和佐料的香辣味，变得鲜嫩起来。
3422942	6	1	回到温馨的家
3422942	6	2	来到大理，环海是不容错过的，洱海沿岸风光风景十分迷人，有安静的小码头、有独具特色的古镇、还有成片的村庄和田野，但是洱海整个环线距离比较长，就算是体力十分好的朋友一天下来也不一定能逛完哦！<br>您可选择一日游产品，也可选择自驾环海，把时间花在游览上！
3422942	6	3	今天推荐您来到这家网红店，品尝鲜美的菌菇锅。牛肝菌、鸡肉菌、干巴菌，锅底再放入少许藏红花，超级暖心。
3422942	6	4	回到温馨的家
3422942	6	5	搭乘自选航班，回到温馨的家。<br>如何前往机场：<br>大理没有公共交通可以直达机场，需要您步行5公里左右的时间。因此我们推荐您打车前往，全程约30公里，50分钟。
3422942	6	6	如果您意犹未尽，选择了傍晚或晚上回去的航班，您今天还可以去游览崇圣寺三塔，下一步中，您可以选购相关的门票。如果您行李不多，可以直接带上，如果行李携带不方便，可以将行李寄存在酒店。<br><br>从酒店前往三塔景区，您只需要乘坐三塔专线的公交车，2元票价，半小时即可抵达。<br>当然，也可以打车前往，全程4.2公里，大约需要10分钟。<br>游览完毕后，您就可以直接打车前往机场了，全程约50分钟，31公里。
3422942	6	7	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
2520032	1	1	国内-飞机-圣彼得堡
2520032	2	1	圣彼得堡
2520032	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
2520032	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）<br>
2520032	2	4	行程酒店仅作推荐，您可以自主选择
2520032	3	1	圣彼得堡——推荐边境小镇维堡包车一日游
2520032	3	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
2520032	3	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
2520032	3	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1024139739	4	1	圣彼得堡_摩尔曼斯克
1024139739	9	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
2520032	3	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
2520032	3	6	这家超级华丽的古典犹如宫廷一般的网红超市，名叫耶利谢耶夫斯基超市(Yeliseyevsky store)。位于俄罗斯首都莫斯科的特维尔大街，地址是Tverskaya大街14号。普希金地铁站出来走几步路就到了。 　　这家超市所在的大厦，于1898年建成，由百万富翁Gregory Eliseev出资建造，但在1917年，苏联苏联建国时候，改制为国有商店，百万富翁Gregory Eliseev就因此离开了苏联，去了法国。 　<br><br>金碧辉煌的装潢搭配上古典气息的格局，使得此另类超市在莫斯科享有盛名，一向都是富豪名流购物的喜爱，据了解，这个超市不提供一站式购物。由于像这样走古典宫廷风格的超市实在少见，因此，也成为许多观光客拍照驻足的地方，俨然成为一新兴景点。
2520032	3	7	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
2520032	3	8	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
2520032	3	9	行程酒店仅作推荐，您可以自主选择
2520032	4	1	圣彼得堡
2520032	4	2	今日推荐在预订下一步选择维堡包车一日游
2520032	4	3	乘车前往维堡  单程约2小时，维堡是个边陲小镇，另有一番萧瑟的味道，这边游客不多，但是风景优美。维堡不仅临海，还有一个淡水湖，有一个中世纪的城堡位于湖中，即为维堡城堡。如果有时间在这里逛逛，从火车站步行10分钟左右还有维堡图书馆，堪称现代北欧建筑的开创性作品。
2520032	4	4	行程酒店仅作推荐，您可以自主选择
2520032	5	1	圣彼得堡-莫斯科
2520032	5	2	前往叶卡捷琳娜宫<br>1、建议出租车前往，行驶时间约40分钟<br>2、可搭乘公共交通，先抵达圣彼得堡后在前往叶卡捷琳娜宫，用时约2小时40分钟。<br>3、我们在后续页面也提供了一日包车游可供您选择。
2520032	5	3	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
2520032	5	4	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的海-地铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
2520032	5	5	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
2520032	5	6	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
2520032	5	7	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
2520032	5	8	行程酒店仅作推荐，您可以自主选择
2520032	5	9	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
2520032	6	1	莫斯科
2520032	6	2	根据航班时间乘机前往莫斯科
2520032	6	3	乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
2520032	6	4	推荐：莫斯科烤鱼<br>俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，然后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
2520032	6	5	推荐入住酒店，您可以自主选择
2520032	7	1	莫斯科-谢尔盖耶夫-莫斯科
2520032	7	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
2520032	7	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
2520032	7	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐经典的一家。
2520032	7	5	行程酒店仅作推荐，您可以自主选择
2520032	8	1	莫斯科-飞机-国内
2520032	8	2	谢镇交通并不方便，建议包车前往<br>*您可以在后续页面选择当地包车服务
2520032	8	3	推荐入住酒店，您可以自主选择
2520032	9	1	国内
2520032	9	2	结束游玩后，提前3个小时抵达机场，办理登机手续，返回国内。
2520032	9	3	部分航班为当天抵达
2520032	9	4	国内
2520032	9	5	抵达国内。结束圆满行程。
2520032	9	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024280216	1	1	出发城市—飞机—莫斯科
1024280216	2	1	莫斯科
1024280216	2	2	根据您选择的航班时间，国际航班至少提前3小时抵达机场，办理登机手续。<br><br>请注意：俄罗斯个人旅游需办理个人旅游签证
1024280216	2	3	入住您选择的酒店，开启愉快的莫斯科之旅。
1024280216	2	4	俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，最后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1024280216	3	1	莫斯科
1024280216	3	2	早上乘坐地铁1号线在运动站（Спортивная）下车，即可参观新圣女修道院和新圣女公墓，行驶时间约为30分钟。
1024280216	3	3	乘坐一站地铁1号线至麻雀山站（Воробьёвые го?ры /Sparrow Hills）下车，即可到达麻雀山。行驶时间约为16分钟。
1024280216	3	4	结束麻雀山观景平台和莫斯科大学的参观之后，搭乘地铁1号线至列宁图书馆站（Библиотека им. Ленина）下车，阿尔巴特街就在附近。行驶时间约为30分钟。
1024280216	3	5	后乘坐地铁在特维尔站、普希金站或契诃夫站下车，在充满俄式复古氛围的普希金咖啡馆用晚餐。这座餐厅历史悠久，分为“药店”、“图书馆”、“温室”、“小酒馆”等多个厅，分别有与主题?应的装潢风格——“药店”的吧台上放着一座称量天平，吧台后装饰成取药抽屉；在“图书馆”厅，用餐者将置身古书之中；“温室”则是靠近街道一侧<br>的玻璃房。店内主要供应俄罗斯菜和法国菜，如果来用晚餐，请尽量正式着装。
1024280216	4	1	莫斯科-推荐金环小镇包车一日游
1024280216	4	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1024280216	4	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1024280216	4	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中经典的一家。
1024280216	4	5	行程酒店仅作推荐，您可以自主选择
1024280216	5	1	莫斯科
1024280216	5	2	今日推荐在预订下一步选择金环小镇包车一日游
1024280216	5	3	含谢尔盖耶夫三一圣大修道院门票
1024280216	5	4	推荐入住酒点，您可以自主选择
1024280216	6	1	察里津诺庄园+卡洛明斯科娅庄园一日游
1024280216	6	2	在酒店享用丰盛的早餐，今日的行程是莫斯科艺术一日游。
1024280216	6	3	乘坐地铁2号线至Novokuznetskaya站，再步行约10分钟即可到达特列季亚科夫美术馆。
1024280216	6	4	推荐餐厅：Му-Му<br>从博物馆出来，前往附近的My-My吃午餐，步行大约5分钟。这是在莫斯科很常见的便餐连锁店，以奶牛为logo，比较容易辨认。餐厅为半自助式，食物与菜肴摆在开放式餐桌上，拿托盘即可点餐，不懂俄语的旅行者也可以轻松应对。
1024280216	6	5	搭乘地铁至克鲁泡特金站（Кропоткинская）或松林站（Боровицкая），步行即可到达普希金造型艺术博物馆。行驶时间约为20分钟。
1024280216	7	1	莫斯科—飞机—出发城市
1024280216	7	2	早上可乘坐公共交通或选择包车前往女皇庄园 沙皇庄园 天然氧吧 避暑胜地，公共交通约为2.5小时。
1024280216	7	3	返回莫斯科，晚上可观看演出。
1024280216	7	4	在此可观看俄罗斯闻名的芭蕾舞、歌剧和音乐剧演出，请提前预订。
1024280216	7	5	俄罗斯民族的饮食很有特点，一般离不开冷、酸、汤、酒、茶。各种冷菜生鲜、酸咸，很具民族特点，其中鱼仔酱、酸黄瓜、冷酸鱼要属俄罗斯有名的3种小吃了。冷酸鱼红润好看，口味酸甜，是一道非常受欢迎的俄式冷菜。
1024280216	8	1	出发地
1024280216	8	2	今日推荐选择购物一日游
1024280216	8	3	市场里的房子都是木建筑，是全国各地来的能工巧匠用手工精雕细刻而成，那些彩色的镂空窗棂令人产生各种遐想，高踞于房梁之上的木头熊憨态可掬，走在市场中，你仿佛置身于一个洋溢着浓浓俄罗斯气息的建筑艺术博物馆中。该市场也被人们称为“博物馆的博物馆”。这里有七个博物馆：伏特加史博物馆、蜡像馆、俄罗斯服装和日用品博物馆、俄罗斯民间故事博物馆、俄罗斯玩具博物馆、俄罗斯大钟博物馆和俄罗斯之醉博物馆。
1024280216	8	4	购物结束后满载而归结束莫斯科的行程，乘坐飞机回到您的家。国际航班请至少提前3小时到机场。
1024280216	8	5	部分航班为当天抵达出发地
1024280216	8	6	出发地
1024280216	8	7	部分航班为第二天抵达出发地
1024280216	8	8	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024139739	1	1	出发地-飞机-圣彼得堡
1024139739	2	1	圣彼得堡
1024139739	2	2	办理登机：根据您所选机票，提前2小时到达相应机场国际出发大厅，自行办理登机手续。<br>参考航班：<br>上海出发：<br>俄罗斯航空 SU209 11:45-16:45 10h
1024139739	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）<br>交通: 机场如何抵达市区：<br>1. 搭机场的Express火车：350RUB一趟，每半小时发一班车，35分钟可以坐到地铁环线上的Белоруская（Beloruskaya）站。机场有自助购票机器，可以直接购买车票。<br>2. 搭巴士：851和851Э可搭直达地铁绿色线左上角的末站Речной вокзал(Rechnoi vokzal)，28RUB每人。需要现场跟司机买票，请提前准备好小额卢布。<br>3. 搭小巴：小巴士是合法的私人巴士，一趟70RUB，和巴士在同一个地方搭949號，也是到同一站Речной вокзал(Rechnoi vokzal)，但耗时较少，70RUB。需提前告知司机下车地点。<br>4. 搭出租车：乘坐出租车可方便快捷地去到市区,机场有很多私家车等候载客,但建议游客乘坐正规出租车。
1024139739	2	4	行程酒店仅作推荐，您可以自主选择
1024139739	2	5	推荐理由：距离莫斯科柏悦酒店1公里，步行可达红场，主打海鲜。
1024139739	3	1	圣彼得堡
1024139739	3	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1024139739	3	3	特色推荐：普希金文学咖啡馆，普希金决斗前喝咖啡处
1024139739	3	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1024139739	3	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1024139739	3	6	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1024139739	3	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1024139739	3	8	行程酒店仅作推荐，您可以自主选择
1024139739	4	2	前往叶卡捷琳娜宫<br>1、建议出租车前往，行驶时间约40分钟<br>2、可搭乘公共交通，先抵达圣彼得堡后在前往叶卡捷琳娜宫，用时约2小时40分钟。<br>3、我们在后续页面也提供了一日包车游可供您选择。
1024139739	4	3	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
1024139739	4	4	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的海  地铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
1024139739	4	5	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1024139739	4	6	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
1024139739	4	7	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
1024139739	4	8	行程酒店仅作推荐，您可以自主选择
1024139739	4	9	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
1024139739	5	1	摩尔曼斯克—捷里别尔卡—摩尔曼斯克
1024139739	5	2	如您选择下午或傍晚的航班，您可以继续游览圣彼得堡市区
1024139739	5	3	根据您选择的航班，至少提前2小时抵达圣彼得堡机场，搭乘班机前往摩尔曼斯克<br><br>抵达后推荐乘坐出租车前往您预订的酒店。
1024139739	5	4	摩尔曼斯克，它深入北极圈内远达300多公里，处于极光带上，如天气晴朗，您可以有机会观测到奇妙的北极光
1024139739	6	1	摩尔曼斯克
1024139739	6	2	『极光贴士』在摩尔曼斯克，推荐三个极光观测点 1.摩尔曼斯克市内 2.洛沃泽罗基地Lovozero 3. 捷里别尔卡Teriberka。<br><br>摩尔曼斯克市内由于有光污染，极难看到极光。要想在摩尔曼斯克看极光的话，可以选择从住宿处预订极光猎人，带你开车去郊外追极光。可以在该自由行产品后续选择：俄罗斯摩尔曼斯克 北极光夜游【2人即成团/专业当地司导/高观测率】相关产品。<br><br>捷里别尔卡Teriberka在摩尔曼斯克的北边，临近北冰洋巴伦支海，出门就能看极光的几率较高，车程单程约3小时。需要注意的是冬天去捷里别尔卡的路会经常因为下雪而封路，一般上午的天气情况会比下午至晚上稳定。携程的当地玩乐商城提供当天往返捷里别尔卡的一天套餐，参考：https://huodong.ctrip.com/ottd-activity/dest/t21925635.html<br><br>洛沃泽罗基地Lovozero在摩尔曼斯克往南，萨米人的栖息地，车程单程约3小时。<br><br>住宿条件摩尔曼斯克市内远远好于洛沃泽罗基地Lovozero和捷里别尔卡Teriberka，洛沃泽罗基地Lovozero和捷里别尔卡Teriberka住宿条件堪忧。行程推荐3晚摩尔曼斯克连住。你可以在后续可选项中选择摩尔曼斯克—捷里别尔卡一日往返短途游。
1024139739	7	1	摩尔曼斯克-飞机-莫斯科
1024139739	7	2	列宁号核动力破冰船每周一、二不对外开放
1024139739	7	3	注意：教堂只游览外观！谢谢！
1024139739	7	4	打卡摩尔曼斯克市中心的最北麦当劳。【最北麦当劳】麦当劳于 2013 年 6 月 28 日开始营业，取代了之前在芬兰境内最北麦当劳。来这里的意义就是为了“最北”。如果运气好的话，可能会在用餐的同时欣赏到极光哦！
1024139739	7	5	前往：【摩尔曼斯克奥克尼雪地项目体验中心(哈士奇拉雪橇、雪地摩托、冰上垂钓)】 与 【打卡全世界北端的金拱门——麦当劳】<br>在摩尔曼斯克奥克尼雪地项目体验中心可以自由体验哈士奇雪橇，在雪地上疾速飞驰，耳边安静得只有呼啸而过的风声，和狗狗们踩踏着雪的轻盈脚步声，眼前则只有漫无边际又纯净无暇的白。亲自驾驶拉普兰地区独有的雪地摩托，驰骋在北极圈上，别提有多威风了！<br><br>之后体验北极圈内必选的一项冬季运动——冰上垂钓，这个项目考验的就是耐寒能力与耐心。要在结冰的湖面上凿开一个冰洞，用一条简单的鱼线挂钩上装上些鲜美的鱼食，再慢慢地将鱼线放入冰洞中，等待贪吃的鱼儿上钩，感受冰钓所带来的无限乐趣。在要离开摩尔曼斯克之际，我们怎么能不去一下全世界北端的金拱门打个卡呢？这家开于2013年的麦当劳，打破了当时罗瓦涅米北麦当劳的记录。对了！别忘了合影，因为人生往往就是需要这样的仪式感！
1024139739	7	6	打卡摩尔曼斯克的网红餐厅：猎人餐厅。<br>特别注意：俄罗斯的很多人气餐馆和咖啡厅都是需要提前预订的，建议预约确认后再前往就餐。
1024139739	7	7	如果前2天未追到极光或者对追极光还意犹未尽的话，今天可以从摩尔曼斯克市内出发，跟随极光猎人。
1024139739	8	1	莫斯科
1024139739	8	2	办理登机：根据您所选机票，提前2小时到达相应机场国际出发大厅，自行办理登机手续。
1024139739	8	3	航班：搭乘班机飞往莫斯科。<br>（具体航班信息请在预订下一步中查看）
1024139739	8	4	机场如何抵达市区：<br>1. 搭机场的Express火车：350RUB一趟，每半小时发一班车，35分钟可以坐到地铁环线上的Белоруская（Beloruskaya）站。机场有自助购票机器，可以直接购买车票。<br>2. 搭巴士：851和851Э可搭直达地铁绿色线左上角的末站Речной вокзал(Rechnoi vokzal)，28RUB每人。需要现场跟司机买票，请提前准备好小额卢布。<br>3. 搭小巴：小巴士是合法的私人巴士，一趟70RUB，和巴士在同一个地方搭949號，也是到同一站Речной вокзал(Rechnoi vokzal)，但耗时较少，70RUB。需提前告知司机下车地点。<br>4. 搭出租车：乘坐出租车可方便快捷地去到市区,机场有很多私家车等候载客,但建议游客乘坐正规出租车。
1024139739	8	5	行程酒店仅作推荐，您可以自主选择
1024139739	9	1	莫斯科-谢尔盖耶夫-莫斯科
1024139739	9	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1024139739	9	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中经典的一家。
1024139739	10	2	谢尔盖耶夫镇交通不方便，今日在预定下一步中选择包车游谢镇。
1024139739	10	3	当天可根据自己的喜好，随意走进一家当地餐馆，体验当地美食哦~<br>
1024139739	10	4	推荐入住酒店，您可以自主选择
1024139739	11	1	抵达出发地
1024139739	11	2	根据您选择的航班，提前3小时抵达机场返回出发地
1024139739	11	3	部分出发地当天抵达
1024139739	11	4	抵达出发地
1024139739	11	5	部分出发地第二天抵达
1024139739	11	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1019686314	1	1	国内-飞机-莫斯科
1019686314	2	1	莫斯科-谢尔盖耶夫（金环小镇）-莫斯科
1019686314	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1019686314	2	3	航班：由出发城市搭乘班机飞往俄罗斯莫斯科。<br>（具体航班信息请在预订下一步中查看）<br>
1019686314	2	4	抵达莫斯科，我们的司机将直接送您前往酒店<br>友情提示：俄罗斯交通比较拥堵，行车时间较长，敬请谅解！ 由于部分景点会遇到不定期闭馆的情况，为了保证您的游览时间，导游将为您根据不同出发日期调整部分行程的参观顺序。
1019686314	2	5	参考酒店，最终以确认单为准
1019686314	3	1	莫斯科
1019686314	3	2	如选择包车套餐，中文司机将带您游览金环小镇——谢尔盖耶夫镇
1019686314	3	3	含谢尔盖耶夫三一圣大修道院门票
1019686314	3	4	晚餐敬请自理
1019686314	3	5	参考酒店，最终以确认单为准
1019686314	4	1	莫斯科-圣彼得堡
1019686314	4	2	您可以在百货商场自由购物
1019686314	4	3	午餐: 方便游玩，尽请自理
1019686314	4	4	重要提示：克里姆林宫是莫斯科热门的景点之一，每逢周四闭馆，并且游客众多。故当天的行程顺序可能因此而发生调整，敬请谅解！<br><br>门票已含
1019686314	4	5	晚餐：方便游玩，敬请自理。
1019686314	4	6	参考酒店，最终以确认单为准
1019686314	5	1	圣彼得堡
1019686314	5	2	酒店内早餐后开始今天的行程
1019686314	5	3	如您预订了火车票，司机将送您只火车站，如您预订的是机票，司机会将您送至机场前往圣彼得堡
1019686314	5	4	抵达圣彼得堡后我们的司机将接您前往酒店
1019686314	5	5	参考酒店，最终以确认单为准<br>
1019686314	6	1	圣彼得堡
1019686314	6	2	酒店内用早餐后，开始今天的行程
1019686314	6	3	外观
1019686314	6	4	门票已含
1019686314	6	5	圣彼得堡是俄罗斯大的港口，渔产丰富，品种繁多，尤其以三文鱼较为鲜美。咸鱼干的肉质和三文鱼相似，配面包吃，別有风味。此外，圣彼得堡快餐店很多，麦当劳、肯德基随处都有。<br>较方便的是土耳其烤肉摊，每个地铁出入口都有几档，大铁棍上插满了鸡肉、羊肉，电炉烤着，要时削下一些，用一张薄面饼一卷，配上洋葱，可做午餐，30卢布/个。再喝点伏特加，一定让你不肯罢手。<br>圣彼得堡也有很多中国餐厅，水平参差，比较老的是上海饭店（Shanghai Restaurant）和筷子餐厅（Chopsticks），在当地也可算得上是具有中国风味的餐厅了。
1019686314	6	6	入内参观，外观彼得保罗大教堂，门票已含
1019686314	6	7	您可以在涅瓦河变观看日落美景
1019686314	6	8	方便游玩，敬请自理。
1019686314	6	9	参考酒店，最终以确认单为准
1019686314	7	1	圣彼得堡-飞机-国内
1019686314	7	2	酒店早餐后开始今日的行程
1019686314	7	3	 夏宫(此处为参观夏宫花园，含门票）
1019686314	7	4	午餐：方便游览，敬请自理
1019686314	7	5	含门票
1019686314	7	6	晚餐: 方便游玩，尽请自理
1019686314	7	7	参考酒店，最终以确认单为准
1019686314	8	1	国内
1019686314	8	2	根据航班，司机将送您前往机场乘机回国
1019686314	8	3	国内
1019686314	8	4	抵达国内。结束圆满行程。 
1019686314	8	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024279184	1	1	国内-飞机-圣彼得堡
1024279184	2	1	圣彼得堡
1024279184	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1024279184	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）<br>
1024279184	2	4	行程酒店仅作推荐，您可以自主选择
1024279184	3	1	圣彼得堡——推荐边境小镇维堡包车一日游
1024279184	3	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1024279184	3	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
1024279184	3	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1024279184	3	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1024279184	3	6	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1024279184	3	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1024279184	4	2	今日推荐在预订下一步选择维堡包车一日游
1024279184	4	3	乘车前往维堡  单程约2小时，维堡是个边陲小镇，另有一番萧瑟的味道，这边游客不多，但是风景优美。维堡不仅临海，还有一个淡水湖，有一个中世纪的城堡位于湖中，即为维堡城堡。如果有时间在这里逛逛，从火车站步行10分钟左右还有维堡图书馆，堪称现代北欧建筑的开创性作品。
1024279184	4	4	行程酒店仅作推荐，您可以自主选择
1024279184	5	1	圣彼得堡-莫斯科
1024279184	5	2	前往叶卡捷琳娜宫<br>1、建议出租车前往，行驶时间约40分钟<br>2、可搭乘公共交通，先抵达圣彼得堡后在前往叶卡捷琳娜宫，用时约2小时40分钟。<br>3、我们在后续页面也提供了一日包车游可供您选择。
1024279184	5	3	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
1024279184	5	4	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的海-地铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
1024279184	5	5	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1024279184	5	6	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
1024279184	5	7	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
1024279184	5	8	行程酒店仅作推荐，您可以自主选择
1024279184	5	9	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
1024279184	6	1	莫斯科
1024279184	6	2	根据航班时间乘机前往莫斯科
1024279184	6	3	乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
1024279184	6	4	推荐：莫斯科烤鱼<br>俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，然后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1024279184	6	5	推荐入住酒店，您可以自主选择
1024279184	7	1	莫斯科-谢尔盖耶夫-莫斯科
1024279184	7	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1024279184	7	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1024279184	7	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐经典的一家。
1024279184	7	5	行程酒店仅作推荐，您可以自主选择
1024279184	8	1	莫斯科-飞机-国内
1024279184	8	2	谢镇交通并不方便，建议包车前往<br>*您可以在后续页面选择当地包车服务
1024279184	8	3	推荐入住酒店，您可以自主选择
1024279184	9	1	国内
1024279184	9	2	结束游玩后，提前3个小时抵达机场，办理登机手续，返回国内。
1024279184	9	3	部分航班为当天抵达
1024279184	9	4	国内
1024279184	9	5	抵达国内。结束圆满行程。
1024279184	9	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1023616233	1	1	国内-飞机-圣彼得堡
1023616233	2	1	圣彼得堡
1023616233	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1023616233	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）<br>
1023616233	2	4	行程酒店仅作推荐，您可以自主选择
1023616233	3	1	圣彼得堡
1023616233	3	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1023616233	3	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
1023616233	3	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1023616233	3	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1023616233	3	6	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1023616233	3	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1023616233	3	8	行程酒店仅作推荐，您可以自主选择
1023616233	4	1	圣彼得堡-莫斯科
1023616233	4	2	前往叶卡捷琳娜宫<br>1、建议出租车前往，行驶时间约40分钟<br>2、可搭乘公共交通，先抵达圣彼得堡后在前往叶卡捷琳娜宫，用时约2小时40分钟。<br>3、我们在后续页面也提供了一日包车游可供您选择。
1023616233	4	3	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
1022963926	5	4	根据您选择的航班，司机将送您前往圣彼得堡机场，请至少提前2小时抵达机场
1022963926	5	5	乘坐您选择的航班前往莫斯科
1023616233	4	4	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的海-地铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
1023616233	4	5	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1023616233	4	6	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
1023616233	4	7	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
1023616233	4	8	行程酒店仅作推荐，您可以自主选择
1023616233	4	9	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
1023616233	5	1	莫斯科-谢尔盖耶夫-莫斯科
1023616233	5	2	您可以选择另外预订机票前往莫斯科，或者购买高铁票（约4-5小时）前往。
1023616233	5	3	乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
1023616233	5	4	推荐：莫斯科烤鱼<br>俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，然后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1023616233	5	5	推荐入住酒店，您可以自主选择
1023616233	6	1	莫斯科
1023616233	6	2	谢镇交通并不方便，建议包车前往<br>*您可以在后续页面选择当地包车服务
1023616233	6	3	推荐入住酒店，您可以自主选择
1023616233	7	1	莫斯科
1023616233	7	2	在酒店享用丰盛的早餐，今日的行程是莫斯科艺术一日游。
1023616233	7	3	乘坐地铁2号线至Novokuznetskaya站，再步行约10分钟即可到达特列季亚科夫美术馆。
1023616233	7	4	推荐餐厅：Му-Му<br>从博物馆出来，前往附近的My-My吃午餐，步行大约5分钟。这是在莫斯科很常见的便餐连锁店，以奶牛为logo，比较容易辨认。餐厅为半自助式，食物与菜肴摆在开放式餐桌上，拿托盘即可点餐，不懂俄语的旅行者也可以轻松应对。
1023616233	7	5	搭乘地铁至克鲁泡特金站（Кропоткинская）或松林站（Боровицкая），步行即可到达普希金造型艺术博物馆。行驶时间约为20分钟。
1023616233	8	1	莫斯科-飞机-国内
1023616233	8	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1023616233	8	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1023616233	8	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐经典的一家。
1023616233	8	5	行程酒店仅作推荐，您可以自主选择
1023616233	9	1	国内
1023616233	9	2	结束游玩后，提前3个小时抵达机场，办理登机手续，返回国内。
1023616233	9	3	部分航班为当天抵达
1023616233	9	4	国内
1023616233	9	5	抵达国内。结束圆满行程。
1023616233	9	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1022963926	1	1	国内-飞机-圣彼得堡
1022963926	2	1	圣彼得堡
1022963926	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1022963926	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）
1022963926	2	4	抵达圣彼得堡，我们的司机将直接送您前往酒店<br>友情提示：俄罗斯交通比较拥堵，行车时间较长，敬请谅解！ 由于部分景点会遇到不定期闭馆的情况，为了保证您的游览时间，导游将为您根据不同出发日期调整部分行程的参观顺序。
1022963926	2	5	以下仅为推荐酒店，实际以您选择的酒店为准
1022963926	3	1	圣彼得堡
1022963926	3	2	今日早餐后乘车游览圣彼得堡市区，晚餐后还可以欣赏一场芭蕾舞歌剧（自理费用）
1022963926	3	3	教堂您可以根据时间，决定是否入内参观
1022963926	3	4	圣彼得堡是俄罗斯大的港口，渔产丰富，品种繁多，尤其以三文鱼较为鲜美。咸鱼干的肉质和三文鱼相似，配面包吃，別有风味。此外，圣彼得堡快餐店很多，麦当劳、肯德基随处都有。<br>较方便的是土耳其烤肉摊，每个地铁出入口都有几档，大铁棍上插满了鸡肉、羊肉，电炉烤着，要时削下一些，用一张薄面饼一卷，配上洋葱，可做午餐，30卢布/个。再喝点伏特加，一定让你不肯罢手。<br>圣彼得堡也有很多中国餐厅，水平参差，比较老的是上海饭店（Shanghai Restaurant）和筷子餐厅（Chopsticks），在当地也可算得上是具有中国风味的餐厅了。
1022963926	3	5	方便游玩，敬请自理。
1022963926	3	6	以下仅为推荐酒店，实际以您选择的酒店为准
1022963926	4	1	圣彼得堡-飞机-莫斯科
1022963926	4	2	今日早餐后继续游玩圣彼得堡，也可前往当地知名餐厅探寻美食。
1022963926	4	3	午餐：方便游览，敬请自理
1022963926	4	4	晚餐: 方便游玩，尽请自理
1022963926	4	5	以下仅为推荐酒店，实际以您选择的酒店为准
1022963926	5	1	莫斯科
1022963926	5	2	早餐后开始今天的行程
1022963926	5	3	如您选择下午的航班，可以游玩夏宫，如您选择上午航班，则推荐夏宫在前2天游玩
1022963926	5	7	以下仅为推荐酒店，实际以您选择的酒店为准
1022963926	6	1	莫斯科-谢尔盖耶夫（金环小镇）-弗拉基米尔
1022963926	6	2	今日早餐后乘车游览莫斯科市区
1022963926	6	3	重要提示：克里姆林宫是莫斯科热门的景点之一，每逢周四闭馆，并且游客众多。故当天的行程顺序可能因此而发生调整，敬请谅解！建议您在预订下一步选择预订门票
1022963926	6	4	第二次世界大战期间，在克留科沃村<br>莫斯科的守卫者们与德国侵略军展开浴血奋战<br>用鲜血和生命保卫了莫斯科，他们当中，有许多人连名字都没有人知道<br>烈士墓的墓碑上刻着这样一句话：<br>Имя твоё неизвестноб， подвиг твой бессмертен。<br>你的名字无人知晓，你的功绩永垂不朽。<br><br>烈士墓由两部分组成，前面是青铜做成的凸形五角星<br>五角星的中央是一个圆形的火炬盆，一年365天燃烧着长明火<br>那句令人震撼的碑文就刻在五角星的前面<br>在烈士墓的左右两边，分别站着两名哨兵<br>他们常年守护者这座无名烈士墓，这就是俄罗斯第一岗哨。<br>从早晨8点到晚上8点，每当整点时，无名烈士墓前都要举行庄严的换岗仪式。<br>瞻仰无名烈士墓和观看换岗仪式成为许多游客在莫斯科游览的一个必不可少的项目。
1022963926	6	5	午餐: 方便游玩，尽请自理
1022963926	6	6	晚餐：方便游玩，敬请自理。
1022963926	6	7	以下仅为推荐酒店，实际以您选择的酒店为准
1022963926	7	1	弗拉基米尔-苏兹达尔-莫斯科
1022963926	7	2	酒店早餐后，驱车前往谢尔盖耶夫游览，他是金环古城之一。作为一座宗教城市和民间工艺品生产基地而为世人所知。收藏着无数古俄罗斯绘画精品、贵金属和宝石古董。之后前往弗拉基米尔，他是一个比莫斯科还老的城市，被誉为古代俄罗斯另一颗珠宝。
1022963926	7	3	含谢尔盖耶夫三一圣大修道院门票
1022963926	7	4	晚餐敬请自理
1022963926	7	5	如有兴趣，您可以自行体验俄式桑拿<br>对俄罗斯人而言，桑拿与烈性的伏特加、精致的套娃一样，是俄罗斯文化的象征之一。<br>上世纪80年代的莫斯科，澡堂与地铁站、公园一样，是人们经常约会的地点。<br>人们喜欢带着酒和酸黄瓜上澡堂，享受完蒸汽再享用美酒佳肴。<br>俄罗斯浴与芬兰浴、土耳其浴和日本浴，有“世界四大名浴”之美称。<br>当地居民为村里的桑拿浴所挑冷水，俄式桑拿通常在木制结构的建筑内进行<br>人们一进到桑拿房里便开始往热石块上浇水，使蒸气释放出来。<br>俄罗斯桑拿的特点是要用桦树枝抽打全身，而不用洗浴液。<br>所以这里的人家夏天都要去森林里采摘嫩桦树枝，储存起来。<br>桑拿浴的高温可以使身上的毛孔扩大，彻底洗净身上的污垢<br>先进入淋浴室，用温水、肥皂洗净全身并擦干皮肤，用浴巾围腰<br>然后进入蒸气浴室，待全身发热，皮肤发红，就进入降温室。<br>有一些寻求刺激的会直接跳入雪中，来个“雪浴”。
1022963926	7	6	以下仅为推荐酒店，实际以您选择的酒店为准；注意：弗拉基米尔由于本身硬件设施有限，无五钻酒店
1022963926	8	1	莫斯科-飞机-国内
1022963926	8	2	早餐后驱车前往苏兹达尔，他是位于俄罗斯西部弗拉基米尔州的一座历史悠久的城市，坐落在一座山丘上一望无际的农田中。这里保存着具有俄罗斯建筑艺术风格的古代建筑群，城内的木质建筑非常有名，几乎所有的公共设施与民居都是木质的。苏兹达尔被誉为“白石之城”和“博物馆之城”，俄罗斯人形容它是“像天堂一样美丽的地方”。
1022963926	8	3	被称为“博物馆城市”的金环小城苏兹达里吸引着无数的游客前往<br>湛蓝的天空，木制建筑，绿树红花掩映着，宛若童话般美丽<br>这里以其众多的名胜古迹和优美的自然风光，被列为世界遗产保护区。<br>这座美丽的小城吸引大家的，不止有美景，还有更多有趣的东西~<br><br>比如，黄瓜节、蜜酒节… 苏兹达尔黄瓜节在每年7月举行，节日的庆祝活动有很多<br>比如：必不可少的音乐会，手工艺品售卖展览及各种黄瓜美食<br>穿着黄瓜衣、带着黄瓜帽、高举小黄瓜的黄瓜节游行……<br>相比黄瓜节，蜜酒节的历史就没那么久啦<br>蜜酒是苏兹达尔的传统饮品，去过那的人都该知道<br>蜜酒在这座小城名气很大，路边就可以看到卖瓶装蜜酒的小摊<br>无论是一般的小饭馆还是大餐厅，蜜酒都是必不可少的饮品！<br>去年9月的第一届蜜酒节，吸引了上万人参加。
1022963926	8	4	抵达莫斯科后，如有时间可以前往阿尔巴特大街购物
1022963926	8	5	以下仅为推荐酒店，实际以您选择的酒店为准
1022963926	9	1	国内
1022963926	9	2	根据航班时间，司陪机场送机，搭乘国际航班返回国内，结束愉快的行程。
1022963926	9	3	请和司机协商出发时间，至少提前3小时抵达机场办理登机手续
1022963926	9	4	个别城市航班可能当天抵达国内
1022963926	9	5	国内
1022963926	9	6	抵达国内。结束圆满行程。 
1022963926	9	7	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024280515	1	1	出发地-飞机-莫斯科
1024280515	2	1	莫斯科
1024280515	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1024280515	2	3	航班：由出发城市搭乘班机飞往俄罗斯莫斯科。<br>（具体航班信息请在预订下一步中查看）<br>
1024280515	2	4	机场如何抵达市区：<br>1. 搭机场的Express火车：350RUB一趟，每半小时发一班车，35分钟可以坐到地铁环线上的Белоруская（Beloruskaya）站。机场有自助购票机器，可以直接购买车票。<br>2. 搭巴士：851和851Э可搭直达地铁绿色线左上角的末站Речной вокзал(Rechnoi vokzal)，28RUB每人。需要现场跟司机买票，请提前准备好小额卢布。<br>3. 搭小巴：小巴士是合法的私人巴士，一趟70RUB，和巴士在同一个地方搭949號，也是到同一站Речной вокзал(Rechnoi vokzal)，但耗时较少，70RUB。需提前告知司机下车地点。<br>4. 搭出租车：乘坐出租车可方便快捷地去到市区,机场有很多私家车等候载客,但建议游客乘坐正规出租车。
1024280515	2	5	行程酒店仅作推荐，您可以自主选择
1024280515	3	1	莫斯科-谢尔盖耶夫-莫斯科
1023450960	8	7	部分航班为第二天抵达出发地
1024280515	3	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1024280515	3	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1024280515	3	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中为经典的一家。
1024280515	3	5	行程酒店仅作推荐，您可以自主选择
1024280515	4	1	莫斯科
1024280515	4	2	谢镇交通并不方便，建议包车前往<br>*您可以在后续页面选择当地包车服务
1024280515	4	3	当天可根据自己的喜好，随意走进一家当地餐馆，体验当地美食哦~<br>
1024280515	4	4	推荐入住酒店，您可以自主选择
1024280515	5	1	莫斯科-飞机-出发地
1024280515	5	2	今天可前往以下景点游览。您也可以在市内逛逛商场或休闲地享用当地的美食。
1024280515	6	1	飞机-出发地 
1024280515	6	2	今天您将搭乘航班返回。收拾好行李后，打车前往机场<br>温馨提示：国际航班建议您至少提前3小时抵达机场，办理相关手续和退税相关事宜。<br>
1024280515	6	3	飞机-出发地 
1024280515	6	4	抵达国内。结束圆满行程。 此天适用于隔天到达的航班。
1024280515	6	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1023450960	1	1	出发城市—飞机—莫斯科
1023450960	2	1	莫斯科
1023450960	2	2	根据您选择的航班时间，国际航班至少提前3小时抵达机场，办理登机手续。<br><br>请注意：俄罗斯个人旅游需办理个人旅游签证
1023450960	2	3	入住您选择的酒店，开启愉快的莫斯科之旅。
1023450960	2	4	俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，最后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1023450960	3	1	莫斯科
1023450960	3	2	早上乘坐地铁1号线在运动站（Спортивная）下车，即可参观新圣女修道院和新圣女公墓，行驶时间约为30分钟。
1023450960	3	3	乘坐一站地铁1号线至麻雀山站（Воробьёвые го?ры /Sparrow Hills）下车，即可到达麻雀山。行驶时间约为16分钟。
1023450960	3	4	结束麻雀山观景平台和莫斯科大学的参观之后，搭乘地铁1号线至列宁图书馆站（Библиотека им. Ленина）下车，阿尔巴特街就在附近。行驶时间约为30分钟。
1023450960	3	5	后乘坐地铁在特维尔站、普希金站或契诃夫站下车，在充满俄式复古氛围的普希金咖啡馆用晚餐。这座餐厅历史悠久，分为“药店”、“图书馆”、“温室”、“小酒馆”等多个厅，分别有与主题?应的装潢风格——“药店”的吧台上放着一座称量天平，吧台后装饰成取药抽屉；在“图书馆”厅，用餐者将置身古书之中；“温室”则是靠近街道一侧<br>的玻璃房。店内主要供应俄罗斯菜和法国菜，如果来用晚餐，请尽量正式着装。
1023450960	4	1	莫斯科-推荐金环小镇包车一日游
1023450960	4	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1023450960	4	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1023450960	4	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中经典的一家。
1023450960	4	5	行程酒店仅作推荐，您可以自主选择
1023450960	5	1	莫斯科
1023450960	5	2	今日推荐在预订下一步选择金环小镇包车一日游
1023450960	5	3	含谢尔盖耶夫三一圣大修道院门票
1023450960	5	4	推荐入住酒点，您可以自主选择
1023450960	6	1	察里津诺庄园+卡洛明斯科娅庄园一日游
1023450960	6	2	在酒店享用丰盛的早餐，今日的行程是莫斯科艺术一日游。
1023450960	6	3	乘坐地铁2号线至Novokuznetskaya站，再步行约10分钟即可到达特列季亚科夫美术馆。
1023450960	6	4	推荐餐厅：Му-Му<br>从博物馆出来，前往附近的My-My吃午餐，步行大约5分钟。这是在莫斯科很常见的便餐连锁店，以奶牛为logo，比较容易辨认。餐厅为半自助式，食物与菜肴摆在开放式餐桌上，拿托盘即可点餐，不懂俄语的旅行者也可以轻松应对。
1023450960	6	5	搭乘地铁至克鲁泡特金站（Кропоткинская）或松林站（Боровицкая），步行即可到达普希金造型艺术博物馆。行驶时间约为20分钟。
1023450960	7	1	莫斯科—飞机—出发城市
1023450960	7	2	早上可乘坐公共交通或选择包车前往女皇庄园 沙皇庄园 天然氧吧 避暑胜地，公共交通约为2.5小时。
1023450960	7	3	返回莫斯科，晚上可观看演出。
1023450960	7	4	在此可观看俄罗斯闻名的芭蕾舞、歌剧和音乐剧演出，请提前预订。
1023450960	7	5	俄罗斯民族的饮食很有特点，一般离不开冷、酸、汤、酒、茶。各种冷菜生鲜、酸咸，很具民族特点，其中鱼仔酱、酸黄瓜、冷酸鱼要属俄罗斯有名的3种小吃了。冷酸鱼红润好看，口味酸甜，是一道非常受欢迎的俄式冷菜。
1023450960	8	1	出发地
1023450960	8	2	今日推荐选择购物一日游
1023450960	8	3	市场里的房子都是木建筑，是全国各地来的能工巧匠用手工精雕细刻而成，那些彩色的镂空窗棂令人产生各种遐想，高踞于房梁之上的木头熊憨态可掬，走在市场中，你仿佛置身于一个洋溢着浓浓俄罗斯气息的建筑艺术博物馆中。该市场也被人们称为“博物馆的博物馆”。这里有七个博物馆：伏特加史博物馆、蜡像馆、俄罗斯服装和日用品博物馆、俄罗斯民间故事博物馆、俄罗斯玩具博物馆、俄罗斯大钟博物馆和俄罗斯之醉博物馆。
1023450960	8	4	购物结束后满载而归结束莫斯科的行程，乘坐飞机回到您的家。国际航班请至少提前3小时到机场。
1023450960	8	5	部分航班为当天抵达出发地
1023450960	8	8	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1021998953	1	1	出发城市—飞机—莫斯科
1021998953	2	1	莫斯科
1021998953	2	2	入住您选择的酒店，开启愉快的莫斯科之旅。
1021998953	2	3	俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，最后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1021998953	3	1	莫斯科
1021998953	3	2	早上乘坐地铁1号线在运动站（Спортивная）下车，即可参观新圣女修道院和新圣女公墓，行驶时间约为30分钟。
1021998953	3	3	乘坐一站地铁1号线至麻雀山站（Воробьёвые го?ры /Sparrow Hills）下车，即可到达麻雀山。行驶时间约为16分钟。
1021998953	3	4	结束麻雀山观景平台和莫斯科大学的参观之后，搭乘地铁1号线至列宁图书馆站（Библиотека им. Ленина）下车，阿尔巴特街就在附近。行驶时间约为30分钟。
1021998953	3	5	后乘坐地铁在特维尔站、普希金站或契诃夫站下车，在充满俄式复古氛围的普希金咖啡馆用晚餐。这座餐厅历史悠久，分为“药店”、“图书馆”、“温室”、“小酒馆”等多个厅，分别有与主题?应的装潢风格——“药店”的吧台上放着一座称量天平，吧台后装饰成取药抽屉；在“图书馆”厅，用餐者将置身古书之中；“温室”则是靠近街道一侧<br>的玻璃房。店内主要供应俄罗斯菜和法国菜，如果来用晚餐，请尽量正式着装。
1021998953	4	1	莫斯科-推荐金环小镇包车一日游
1021998953	4	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1021998953	4	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1021998953	4	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中为经典的一家。
1021998953	4	5	行程酒店仅作推荐，您可以自主选择
1021998953	5	1	莫斯科
1021998953	5	2	含谢尔盖耶夫三一圣大修道院门票
1021998953	5	3	推荐入住酒点，您可以自主选择
1021998953	6	1	察里津诺庄园+卡洛明斯科娅庄园一日游
1021998953	6	2	在酒店享用丰盛的早餐，今日的行程是莫斯科艺术一日游。
1021998953	6	3	乘坐地铁2号线至Novokuznetskaya站，再步行约10分钟即可到达特列季亚科夫美术馆。
1021998953	6	4	推荐餐厅：Му-Му<br>从博物馆出来，前往附近的My-My吃午餐，步行大约5分钟。这是在莫斯科很常见的便餐连锁店，以奶牛为logo，比较容易辨认。餐厅为半自助式，食物与菜肴摆在开放式餐桌上，拿托盘即可点餐，不懂俄语的旅行者也可以轻松应对。
1021998953	6	5	搭乘地铁至克鲁泡特金站（Кропоткинская）或松林站（Боровицкая），步行即可到达普希金造型艺术博物馆。行驶时间约为20分钟。
1021998953	7	1	莫斯科—飞机—出发城市
1021998953	7	2	早上可乘坐公共交通或选择包车前往女皇庄园 沙皇庄园 天然氧吧 避暑胜地，公共交通约为2.5小时。
1021998953	7	3	返回莫斯科，晚上可观看演出。
1021998953	7	4	在此可观看俄罗斯闻名的芭蕾舞、歌剧和音乐剧演出，请提前预订。
1021998953	7	5	俄罗斯民族的饮食很有特点，一般离不开冷、酸、汤、酒、茶。各种冷菜生鲜、酸咸，很具民族特点，其中鱼仔酱、酸黄瓜、冷酸鱼要属俄罗斯有名的3种小吃了。冷酸鱼红润好看，口味酸甜，是一道非常受欢迎的俄式冷菜。
1021998953	8	1	飞机—出发城市
1021998953	8	2	今日推荐选择购物一日游
1021998953	8	3	市场里的房子都是木建筑，是全国各地来的能工巧匠用手工精雕细刻而成，那些彩色的镂空窗棂令人产生各种遐想，高踞于房梁之上的木头熊憨态可掬，走在市场中，你仿佛置身于一个洋溢着浓浓俄罗斯气息的建筑艺术博物馆中。该市场也被人们称为“博物馆的博物馆”。这里有七个博物馆：伏特加史博物馆、蜡像馆、俄罗斯服装和日用品博物馆、俄罗斯民间故事博物馆、俄罗斯玩具博物馆、俄罗斯大钟博物馆和俄罗斯之醉博物馆。
1021998953	8	4	购物结束后满载而归结束莫斯科的行程，乘坐飞机回到您的家。国际航班请至少提前3小时到机场。
1021998953	8	5	飞机—出发城市
1021998953	8	6	返程航班有的会当天抵达有的会隔天抵达。此为隔天抵达，8天行程的最后一天。
1021998953	8	7	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1018710340	1	1	国内-飞机-圣彼得堡
1018710340	2	1	圣彼得堡
1018710340	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1018710340	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）<br>
1018710340	2	4	行程酒店仅作推荐，您可以自主选择
1018710340	3	1	圣彼得堡-莫斯科
1018710340	3	2	地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1018710340	3	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
1018710340	3	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1018710340	3	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1019560466	3	5	行程酒店仅作推荐，您可以自主选择
1018710340	3	6	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1018710340	3	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1018710340	3	8	行程酒店仅作推荐，您可以自主选择
1018710340	4	1	莫斯科
1018710340	4	2	交通：5月至9月期间，可在冬宫河岸边的码头乘船前往，票价成人750卢布，往返1100卢布，学生450卢布，单程仅40分钟。乘船到达的地方就是下花园入口处。其余时间搭乘地铁红线至Автово站，出站后经右侧地下通道，从右侧出口上去可看见公交站，换乘公交200、210路至Правленская站，下车便是上花园大门入口处。
1018710340	4	3	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1018710340	4	4	您可以选择乘高铁或者飞机前往莫斯科（需要自行预订）
1018710340	4	5	乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
1018710340	4	6	推荐：莫斯科烤鱼<br>俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，最后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1018710340	4	7	推荐入住酒店，您可以自主选择
1018710340	5	1	莫斯科-飞机-迪拜
1018710340	5	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1018710340	5	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1018710340	5	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中为经典的一家。
1018710340	5	5	行程酒店仅作推荐，您可以自主选择
1018710340	6	1	迪拜
1018710340	6	2	交通：搭乘地铁1号线至Universitet站后，向北步行约500米可到。
1018710340	6	3	推荐：冷酸鱼<br>俄罗斯民族的饮食很有特点，一般离不开冷、酸、汤、酒、茶。各种冷菜生鲜、酸咸，很具民族特点，其中鱼仔酱、酸黄瓜、冷酸鱼要属俄罗斯有名的3种小吃了。冷酸鱼红润好看，口味酸甜，是一道非常受欢迎的俄式冷菜。
1018710340	6	4	今日乘机前往迪拜游览
1018710340	6	5	到达迪拜后直接入住酒店休息。<br>T1航站楼计程车停靠位置位于出大厅直走方向；T2计程车停靠位置位于出大厅右转尽头；T3停靠位置位于靠近Exit 2左手位。<br>机场计程车专门从机场接到乘客送至任何地方。所有计程车没有什么区别，只有起步价的区别。<br>
1018710340	6	6	推荐入住酒店，您可以选择其他酒店
1018710340	7	1	迪拜
1018710340	7	2	抵达国内。结束圆满行程。 
1018710340	7	3	交通：搭乘地铁绿线至Al Ras Station站下车；搭乘公交车4、13、17、64、C7、X23路等至Gold Souq Bus Station External下车；搭乘公交车17路至Sabkha, Bus Station 2站下车；搭乘公交车C28路至Deira, Post Office站下车，再步行前往。
1018710340	7	4	推荐：阿拉伯烧烤<br>阿联酋的特色烧烤包括：阿拉伯烤鸡、阿拉伯烤牛、阿拉伯烤羊。再搭配阿拉伯风味秘制酱料，堪称一绝。
1018710340	7	5	交通：可乘坐地铁绿线至Al Fahidi Metro Station 2站或Al Ghubaiba Metro Station 2站下车，下车后步行约10分钟即可到达。
1018710340	7	6	推荐入住酒店，您可以自主选择
1018710340	8	1	迪拜-回国
1018710340	8	2	交通：乘坐轻轨（8:00-22:00）至棕榈岛，轻轨共设有3站，高峰时期约9分钟一班，其余时段15-20分钟一班，往返票价25迪拉姆。 
1018710340	8	3	交通：乘坐地铁M红线至Burj Khalifa/Dubai Mall Metro Station 2站下车；亦可乘坐公交27、29、F13到达。
1018710340	8	4	推荐：小拼盘<br>把胡姆斯（Hummus）、法拉费（Fallafel）、蔬菜沙拉拼在一起，再加上烤肉、烤茄子、西红柿、黄瓜和胡萝卜片，并以阿拉伯烤饼做主食，就像是一份阿拉伯美食的小杂烩。如果想要全方位体验阿拉伯美食，不妨点这么一个小拼盘吧。
1018710340	8	5	下午前往购物中心，享受买买买的乐趣
1018710340	8	6	推荐入住酒店，您可以自主选择其他
1018710340	8	7	迪拜-回国
1018710340	8	8	请预留足够时间前往机场
1018710340	8	9	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024126518	1	1	国内-飞机-圣彼得堡
1024126518	2	1	圣彼得堡
1024126518	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1024126518	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）<br>
1024126518	2	4	行程酒店仅作推荐，您可以自主选择
1024126518	3	1	圣彼得堡
1024126518	3	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1024126518	3	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
1024126518	3	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1024126518	3	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1024126518	3	6	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1019560466	4	1	圣彼得堡
1024126518	3	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1024126518	3	8	行程酒店仅作推荐，您可以自主选择
1024126518	4	1	圣彼得堡-莫斯科
1024126518	4	2	前往叶卡捷琳娜宫<br>1、建议出租车前往，行驶时间约40分钟<br>2、可搭乘公共交通，先抵达圣彼得堡后在前往叶卡捷琳娜宫，用时约2小时40分钟。<br>3、我们在后续页面也提供了一日包车游可供您选择。
1024126518	4	3	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
1024126518	4	4	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的海  地铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
1024126518	4	5	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1024126518	4	6	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
1024126518	4	7	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
1024126518	4	8	行程酒店仅作推荐，您可以自主选择
1024126518	4	9	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
1024126518	5	1	莫斯科
1024126518	5	2	根据航班时间乘机前往莫斯科
1024126518	5	3	乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
1024126518	5	4	推荐：莫斯科烤鱼<br>俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，然后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1024126518	5	5	推荐入住酒店，您可以自主选择
1024126518	6	1	莫斯科——巴库
1024126518	6	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1024126518	6	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1024126518	6	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中经典的一家。
1024126518	6	5	行程酒店仅作推荐，您可以自主选择
1024126518	7	1	巴库——世界文化遗产老城
1024126518	7	2	根据您选择的航班，提前3小时抵达机场，乘飞机前往巴库；抵达巴库机场后可以直接在机场办理落地签
1024126518	7	3	如机场出发，去往市区可以选择机场大巴，坐机场大巴需要首先购买名为“BAKIKART”交通卡，该交通卡机场大巴、地铁、公交通用，在机场航站楼售票机可以买到。机场大巴发车频次大致是30分钟一班，19:00以后40分钟一班，21:00以后是1小时一班，运营时间是早6:00至晚上23:00
1024126518	8	1	巴库-飞机-国内
1024126518	8	2	经过一晚上的休息后，今天一天的行程在巴库市中心开展。
1024126518	8	3	巴库老城被列为世界文化遗产，老城内包括许多景点，在老城内漫步的同时，可沿途观赏以下景点。
1024126518	8	4	有登山缆车道可以前往火焰山，1个马纳特/1人次；到达山岗后在观景平台上可以俯瞰老城全景，日落时分，可以说是个极好的观赏点了。
1024126518	8	5	晚餐可以试试当地特色的饮食，阿塞拜疆菜品多以烤制为主，可以试试当地烤羊排、烤牛肉和烤鸡，配以当地人的主食烤大饼。
1024126518	9	1	国内
1024126518	9	2	如您选择傍晚的航班，上午您可以继续游览巴库<br><br>阿利耶夫文化中心，乘坐地铁到达Nariman Narimanov站，出站后步行几分钟即可到达。<br>这座建筑由天马行空的流线所构成，外观新颖奇特极具现代感，建筑外形新颖奇特现代，呈现一种流体外形，由地理地形自然延伸堆叠而出，并盘卷出各个独立功能区域。阿利耶夫文化中心包括一个博物馆、图书馆和会议中心。
1024126518	9	3	巴库地毯博物馆的外形就独具创意，建筑物本身看上去就像一张滚动的地毯。里面收藏了需要地毯，可以探索亚欧地毯多彩的文化
1024126518	9	4	结束游玩后，提前3个小时抵达机场，办理登机手续，返回国内。
1024126518	9	5	部分出发地的航班可能为当天抵达出发地
1024126518	9	6	国内
1024126518	9	7	部分航班第二天抵达国内。结束圆满行程。
1024126518	9	8	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1024149421	1	1	国内-飞机-圣彼得堡
1024149421	2	1	圣彼得堡
1024149421	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1024149421	2	3	航班：由出发城市搭乘班机飞往俄罗斯圣彼得堡。<br>（具体航班信息请在预订下一步中查看）<br>
1024149421	2	4	行程酒店仅作推荐，您可以自主选择
1024149421	3	1	圣彼得堡
1024149421	3	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1019560466	3	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1019560466	3	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中为经典的一家。
1024149421	3	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
1024149421	3	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1024149421	3	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1024149421	3	6	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1024149421	3	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1024149421	3	8	行程酒店仅作推荐，您可以自主选择
1024149421	4	1	圣彼得堡-莫斯科
1024149421	4	2	前往叶卡捷琳娜宫<br>1、建议出租车前往，行驶时间约40分钟<br>2、可搭乘公共交通，先抵达圣彼得堡后在前往叶卡捷琳娜宫，用时约2小时40分钟。<br>3、我们在后续页面也提供了一日包车游可供您选择。
1024149421	4	3	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
1024149421	4	4	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的海  地铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
1024149421	4	5	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1024149421	4	6	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
1024149421	4	7	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
1024149421	4	8	行程酒店仅作推荐，您可以自主选择
1024149421	4	9	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
1024149421	5	1	莫斯科
1024149421	5	2	根据航班时间乘机前往莫斯科
1024149421	5	3	乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
1024149421	5	4	推荐：莫斯科烤鱼<br>俄式烤鱼需要放入一些黄油炒过的番茄酱，与奶汁掺杂起来，透出一种粉红色。 莫斯科烤鱼与俄式烤鱼有着简单的差别，在莫斯科餐厅则是地道的莫斯科烤鱼。莫斯科烤鱼选用的是鲈鱼，先把鲈鱼煎熟，再在鲈鱼表面放上烧好的蘑菇、鸡蛋、洋葱，然后在上面覆盖上一层洁白的奶汁，再撒上一些芝士。
1024149421	5	5	推荐入住酒店，您可以自主选择
1024149421	6	1	莫斯科-谢尔盖耶夫-莫斯科
1024149421	6	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1024149421	6	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1024149421	6	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中经典的一家。
1024149421	6	5	行程酒店仅作推荐，您可以自主选择
1024149421	7	1	莫斯科-飞机-阿拉木图
1024149421	7	2	谢镇交通并不方便，建议包车前往<br>*您可以在后续页面选择当地包车服务
1024149421	7	3	推荐入住酒店，您可以自主选择
1024149421	8	1	阿拉木图
1024149421	8	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1024149421	8	3	航班：由出发城市搭乘班机飞往哈萨克斯坦旧都——阿拉木图， <br>（具体航班信息请在预订下一步中查看）
1024149421	8	4	小贴士：抵达后建议先在机场把美金更换哈萨克斯坦当地货币坚戈，汇率约为1:180<br><br>抵达市区交通：<br><br>1.乘坐公共交通；搭乘公交车79路、86路、92路可抵达市区，约80坚戈/人<br>2.乘坐出租车：注意，当地招揽的出租车多为私家车，务必确认好价格后再搭乘，机场-市区单程价格约2000坚戈/人
1024149421	8	5	行程酒店仅作推荐，您可以自主选择
1024149421	9	1	阿拉木图（推荐大阿拉木图湖一日游）
1024149421	9	2	以下行程仅供参考，您可以自行选择游览内容
1024149421	9	3	行程酒店仅作推荐，您可以自主选择
1024149421	10	1	阿拉木图 - 各地
1024149421	10	2	今日推荐在当地包车前往中亚明珠——大阿拉木图湖游玩
1024149421	10	3	行程酒店仅作推荐，您可以自主选择
1024149421	11	1	国内
1024149421	11	2	请根据航班时间，提前抵达机场办理值机手续，搭乘航班返回出发地
1024149421	11	3	国内
1024149421	11	4	部分航班第二天抵达国内。结束圆满行程。
1024149421	11	5	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1019560466	1	1	国内-飞机-莫斯科
1019560466	2	1	莫斯科
1019560466	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1019560466	2	3	航班：由出发城市搭乘班机飞往俄罗斯莫斯科。<br>（具体航班信息请在预订下一步中查看）<br>
1019560466	2	4	行程酒店仅作推荐，您可以自主选择
1019560466	3	1	莫斯科-飞机-圣彼得堡
1019560466	3	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1019560466	4	2	早餐后，乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
1019560466	4	3	 
1019560466	4	4	Гарелея楼上的marketplace有自助式的面、汤、饭可和胃。<br>地址：在火车站对面，李果夫大街和涅瓦大街交界处
1019560466	4	5	行程酒店仅作推荐，您可以自主选择
1019560466	5	1	圣彼得堡
1019560466	5	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1019560466	5	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
1019560466	5	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1019560466	5	5	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1019560466	5	6	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1019560466	5	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1019560466	5	8	行程酒店仅作推荐，您可以自主选择
1019560466	6	1	圣彼得堡-飞机-索契
1019560466	6	2	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
1019560466	6	3	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
1019560466	6	4	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1019560466	6	5	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
1019560466	6	6	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
1019560466	6	7	行程酒店仅作推荐，您可以自主选择
1019560466	6	8	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
1019560466	7	1	索契
1019560466	7	2	前往机场，乘坐内陆航班前往：索契 
1019560466	7	3	到酒店安顿好后，午餐推荐有名的：Белые ночи白夜餐厅，步行即可到达
1019560466	7	4	酒店附近，步行即可到达
1019560466	7	5	傍晚可去酒店楼下的黑海滨海大道闲逛，那里捷克菜或亚美尼亚菜都做得可圈可点。
1019560466	7	6	行程酒店仅作推荐，您可以自主选择
1019560466	7	7	到达索契机场后，我们的司机将接您送回您预定的酒店休息
1019560466	8	1	索契
1019560466	8	2	今天起得早些，早餐后，在酒店出巷子处乘坐105路公交车或者105c路定向出租车，玫瑰庄园站（Курорт “Роза-хутор”）下、乘坐135路公交车，玫瑰庄园站（Курорт “Роза-хутор”）下
1019560466	8	3	游览时间9:00-18:00（17:00后停止售票），滑雪和单板滑雪区“Circus-2”9:30-16:30，滑雪和单板滑雪区“К-3”9:30-17:00，滑雪运动15:00后停止售票。<br>门票信息：<br>门市价：900.0卢布<br>游览门票：成人900卢布，6-15岁儿童500卢布。通票（包含滑雪等活动）：成人1600卢布，学生1000卢布，6-15岁儿童900卢布。<br><br>可租用滑雪设备，请选择合适的雪道，玫瑰山庄部分设置为奥运赛道，务必注意安全。<br>午餐：自理。<br>山顶有小卖部可喝些热饮吃简单午餐。
1019560466	8	4	山脚下的村庄有许多不错的特色餐馆。<br>推荐菜品：索契红菜汤
1019560466	8	5	行程酒店仅作推荐，您可以自主选择
1019560466	9	1	索契-飞机-国内
1019560466	9	2	早餐后，乘坐公交124s或火车到达Олимпийский Парк火车站，到达景点：索契奥林匹克公园
1019560466	9	3	可以租用自行车或电动车在园区内游览，索契冬奥会举办场地。<br>午餐：园区内自理
1019560466	9	4	位于索契的中心区，这里是非常出名的温泉度假胜地，有别于其他温泉的是，这里的温泉蕴含硫磺物质，对于皮肤愈合，调节等有一定的效果，每年有超过40000名游客来到这里感受马采斯塔温泉的神奇。
1019560466	9	5	返回市区，在黑海之滨漫步，一直可走到远处的灯塔，观看黑海日落<br>黑海边推荐菜：烤肉、芝士酥饼
1019560466	9	6	行程酒店仅作推荐，您可以自主选择
1019560466	10	1	国内
1019560466	10	2	带奥运标志的纪念品，已遍布索契的每个角落,不光有钥匙圈、绒毛玩具和冰箱贴，还有完全不属于纪念品类别的物品。这里的所有奥运产品都有授权，并且所有商店的售价都是统一的。 <br>推荐购物地点：奥林匹斯购物中心
1019560466	10	3	提前3个小时抵达机场，办理登机手续，返回国内。
1019560466	10	4	国内
1019560466	10	5	带着温馨回忆回到国内。
1019560466	10	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1023314344	1	1	出发地-飞机-莫斯科
1023314344	2	1	莫斯科
1023314344	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1023314344	2	3	航班：由出发城市搭乘班机飞往俄罗斯莫斯科。<br>（具体航班信息请在预订下一步中查看）<br>
1023314344	2	4	机场如何抵达市区：<br>1. 搭机场的Express火车：350RUB一趟，每半小时发一班车，35分钟可以坐到地铁环线上的Белоруская（Beloruskaya）站。机场有自助购票机器，可以直接购买车票。<br>2. 搭巴士：851和851Э可搭直达地铁绿色线左上角的末站Речной вокзал(Rechnoi vokzal)，28RUB每人。需要现场跟司机买票，请提前准备好小额卢布。<br>3. 搭小巴：小巴士是合法的私人巴士，一趟70RUB，和巴士在同一个地方搭949號，也是到同一站Речной вокзал(Rechnoi vokzal)，但耗时较少，70RUB。需提前告知司机下车地点。<br>4. 搭出租车：乘坐出租车可方便快捷地去到市区,机场有很多私家车等候载客,但建议游客乘坐正规出租车。
1023314344	2	5	行程酒店仅作推荐，您可以自主选择
1023314344	3	1	莫斯科-谢尔盖耶夫-莫斯科
1023314344	3	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1023314344	3	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1023314344	3	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中经典的一家。
1023314344	3	5	行程酒店仅作推荐，您可以自主选择
1023314344	4	1	莫斯科
1023314344	4	2	谢镇交通并不方便，建议包车前往<br>*您可以在后续页面选择当地包车服务
1023314344	4	3	当天可根据自己的喜好，随意走进一家当地餐馆，体验当地美食哦~<br>
1023314344	4	4	行程酒店仅作推荐，您可以自主选择
1023314344	5	1	莫斯科-飞机-叶卡捷琳堡
1023314344	5	2	今天可前往以下景点游览。您也可以在市内逛逛商场或休闲地享用当地的美食。
1023314344	5	3	行程酒店仅作推荐，您可以自主选择
1023314344	6	1	叶卡捷琳堡
1023314344	6	2	今天您将搭乘航班前往横跨亚洲的城市，同时也是2018年世界杯举办场地之一的叶卡捷琳堡。<br><br>叶卡捷琳堡是是一七二三年女皇叶卡捷琳娜一世的名字命名的，也是叶利钦起家的城市，同时也是俄罗斯醉后一位沙皇尼古拉二世的断命之地
1023314344	6	3	抵达后，科利佐沃机场机场距离叶卡捷琳堡16公里。<br><br>您可以在机场乘坐地铁，公交车或者电车，出租车前往市区
1023314344	7	1	叶卡捷琳堡-飞机-出发地
1023314344	7	2	今日继续游览叶卡捷琳堡，推荐前往亚欧分界线纪念碑，2018年 世界杯改造后的奇葩球场，在摩天大楼Vysotsky露天景观台俯瞰整个城市。
1023314344	7	3	1905广场是叶卡捷琳堡热闹的地段，也是各种公交线路的枢纽，您可以在这里购物或用餐
1023314344	8	1	飞机-出发地 
1023314344	8	2	今天您将搭乘航班返回。收拾好行李后，打车前往机场<br>温馨提示：国际航班建议您至少提前3小时抵达机场，办理相关手续和退税相关事宜。<br>
1023314344	8	3	部分航班当天抵达
1023314344	8	4	飞机-出发地 
1023314344	8	5	抵达国内。结束圆满行程。 此天适用于隔天到达的航班。
1023314344	8	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
1021972528	1	1	国内-飞机-莫斯科
1021972528	2	1	莫斯科
1021972528	2	2	办理登机：根据您所选机票，提前3小时到达相应机场国际出发大厅，自行办理登机手续。 
1021972528	2	3	航班：由出发城市搭乘班机飞往俄罗斯莫斯科。<br>（具体航班信息请在预订下一步中查看）<br>
1021972528	2	4	我们为您安排好接驳服务，司机师傅已经在机场迎宾口举牌等候您，送您到预定酒店入住<br> 
1021972528	2	5	行程酒店仅作推荐，您可以自主选择
1021972528	3	1	莫斯科-圣彼得堡
1021972528	3	2	前往红场交通：可乘坐地铁至Площадь Революции站下车，向西南方步行2分钟即可。
1021972528	3	3	景点相隔近，步行前往游览即可。<br>圣瓦西里升天大教堂、克里姆林宫需要另买门票排队入内
1021972528	3	4	特色推荐：古姆百货顶楼的Столовая No.72，是自助式俄餐中为经典的一家。
1021972528	3	5	行程酒店仅作推荐，您可以自主选择
1021972528	4	1	圣彼得堡
1021972528	4	2	早餐后，乘坐地铁到达Arbatskaya 站，前往景点：阿尔巴特大街<br>如果你想买些文艺纪念品，这里一定不能错过
1021972528	4	3	Гарелея楼上的marketplace有自助式的面、汤、饭可和胃。<br>地址：在火车站对面，李果夫大街和涅瓦大街交界处
1021972528	4	4	行程酒店仅作推荐，您可以自主选择
1021972528	5	1	圣彼得堡
1021972528	5	2	早餐后，搭乘7、10、24、191路公交；或1、7、10、11路无轨电车；<br>地铁5号线到Адмиралтейская站(出站后左转到路口，右转直走至涅瓦大街，左转到头，在右手边便可看见冬宫广场，过马路直走便是参谋总部大楼，对面就是冬宫
1021972528	5	3	特色推荐：从冬宫出来后，向火车站方向沿涅瓦街走10分钟，街角星巴克处右转，再向前500米有家ground层的格鲁吉亚餐厅，非常美味。<br>或，普希金文学咖啡馆，普希金决斗前喝咖啡处，文艺情怀大于口味，价格较贵
1021972528	5	4	向前继续步行3分钟，马路对面的道路尽头便是恢弘华丽的滴血大教堂
1021972528	5	5	不喜购物的话来这里，可在河滩边观看日落<br>地铁2号线Gorkovskaya站
1021972528	5	6	推荐店铺：<br>化妆品-Летуаль、Ривгош<br>工艺品-Гостиный Дворь<br>甜品店-北方咖啡馆，地道俄罗斯甜品，称斤卖，商标是蓝色圆形的，中间是只北极熊<br>综合性商场：Гарелея
1021972528	5	7	特色推荐：Теремок或Чайная ложка俄式煎饼巨头<br>或Нихао，中餐厅，标准的中式菜，人均100-200CNY
1021972528	5	8	行程酒店仅作推荐，您可以自主选择
1021972528	6	1	圣彼得堡—飞机—索契
1021972528	6	2	早餐后，前往地铁至Спортивная站，到达冬宫桥旁码头
1021972528	6	3	乘坐快船，沿涅瓦河行驶40分钟，票价800卢布/人，在旅游旺季10:00-18:00内，有多艘船次从这里出发；<br>另外可以从波罗的铁站出发，乘坐K404路公交；或从汽车站地铁站出发，乘坐K343路小型公交，约40分钟至1小时时间。
1021972528	6	4	夏宫花园内有不少小摊位，热狗味道不错，还有沾甘梅粉的煮玉米值得一试
1021972528	6	5	建议回涅瓦街吃，品类丰富，mama roma或沿途韩餐都是比较正宗的。
1021972528	6	6	回酒店休整，或找间咖啡店小坐。<br>午夜1点左右，打车到达冬宫桥附近，费用200卢以内，观赏开桥
1021972528	6	7	行程酒店仅作推荐，您可以自主选择
1021972528	6	8	观赏开桥：<br>可购买游船票或在桥边等待，每个大桥的打开时间有一定的间隔，每个大桥间隔20-30分钟时间。时间每年不同，以官方公布为准，大概4-11月。具体每天的时间为凌晨1：10左右开始，一般一点钟人群就开始聚集等待仪式开始。<br>开桥的地点为大涅瓦河上的一系列大桥（冬宫北侧沿河一系列大桥），极具观赏性的是冬宫旁边的大桥，从正中间打开桥面的1/2，不过打开后很快闭合。接下来沿河的各个大桥由外向内（海湾为外侧）依次打开，煞是好看。<br>深秋请注意防寒保暖，夜间非常冷。
1021972528	7	1	索契
1021972528	7	2	前往机场，乘坐内陆航班前往索契 
1021972528	7	3	到酒店安顿好后，午餐推荐有名的：Белые ночи白夜餐厅，步行即可到达
1021972528	7	4	到达索契机场后，请自行前往酒店
1021972528	7	5	酒店附近，步行即可到达
1021972528	7	6	傍晚可去酒店楼下的黑海滨海大道闲逛，那里捷克菜或亚美尼亚菜都做得可圈可点。
1021972528	7	7	行程酒店仅作推荐，您可以自主选择
1021972528	8	1	索契
1021972528	8	2	今天起得早些，早餐后，在酒店出巷子处乘坐105路公交车或者105c路定向出租车，玫瑰庄园站（Курорт “Роза-хутор”）下、乘坐135路公交车，玫瑰庄园站（Курорт “Роза-хутор”）下
1021972528	8	3	游览时间9:00-18:00（17:00后停止售票），滑雪和单板滑雪区“Circus-2”9:30-16:30，滑雪和单板滑雪区“К-3”9:30-17:00，滑雪运动15:00后停止售票。<br>门票信息：<br>门市价：900.0卢布<br>游览门票：成人900卢布，6-15岁儿童500卢布。通票（包含滑雪等活动）：成人1600卢布，学生1000卢布，6-15岁儿童900卢布。<br><br>可租用滑雪设备，请选择合适的雪道，玫瑰山庄部分设置为奥运赛道，务必注意安全。<br>午餐：自理。<br>山顶有小卖部可喝些热饮吃简单午餐。
1021972528	8	4	山脚下的村庄有许多不错的特色餐馆。<br>推荐菜品：索契红菜汤
1021972528	8	5	行程酒店仅作推荐，您可以自主选择
1021972528	9	1	索契-飞机-国内
1021972528	9	2	早餐后，乘坐公交124s或火车到达Олимпийский Парк火车站，到达景点：索契奥林匹克公园
1021972528	9	3	可以租用自行车或电动车在园区内游览，索契冬奥会举办场地。<br>午餐：园区内自理
1021972528	9	4	返回市区，在黑海之滨漫步，一直可走到远处的灯塔，观看黑海日落<br>黑海边推荐菜：烤肉、芝士酥饼
1021972528	9	5	行程酒店仅作推荐，您可以自主选择
1021972528	10	1	国内
1021972528	10	2	带奥运标志的纪念品，已遍布索契的每个角落,不光有钥匙圈、绒毛玩具和冰箱贴，还有完全不属于纪念品类别的物品。这里的所有奥运产品都有授权，并且所有商店的售价都是统一的。 <br>推荐购物地点：奥林匹斯购物中心
1021972528	10	3	提前3个小时抵达机场，办理登机手续，返回国内。
1021972528	10	4	国内
1021972528	10	5	带着温馨回忆回到国内。
1021972528	10	6	本产品支持信用卡、网银/第三方、礼品卡、储蓄卡、现金余额、拿去花支付，具体以支付页为准。
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."user" (user_id, user_password, user_name) FROM stdin;
1900327840@qq.com	ba3253876aed6bc22d4a6ff53d8406c6ad864195ed144ab5c87621b6c233b548baeae6956df346ec8c17f5ea10f35ee3cbc514797ed7ddd3145464e2a0bab413	lxh
GuiHuaLinked@gmail.com	ba3253876aed6bc22d4a6ff53d8406c6ad864195ed144ab5c87621b6c233b548baeae6956df346ec8c17f5ea10f35ee3cbc514797ed7ddd3145464e2a0bab413	刘湘海
\.


--
-- Data for Name: user_image; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_image (user_id, image_address) FROM stdin;
1900327840@qq.com	/userImage/1900327840@qq.com/254280-102.jpg
GuiHuaLinked@gmail.com	/images/backgrund-1.jpg
\.


--
-- Data for Name: user_raider; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_raider (user_id, raider_id) FROM stdin;
1900327840@qq.com	190032784020200729838956
1900327840@qq.com	46368
1900327840@qq.com	110407
\.


--
-- Data for Name: user_save_raider; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_save_raider (user_id, raider_id, save_date) FROM stdin;
1900327840@qq.com	13591	2020-07-29
1900327840@qq.com	13243	2020-07-30
\.


--
-- Data for Name: user_star_raider; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_star_raider (user_id, raider_id, star_date) FROM stdin;
1900327840@qq.com	13243	2020-07-27
\.


--
-- Data for Name: user_travel_booking; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_travel_booking (user_id, travel_id, travel_price, book_date) FROM stdin;
1900327840@qq.com	1009991988	16786	2020-07-18
1900327840@qq.com	1022900400	15558	2020-07-18
\.


--
-- Data for Name: user_travel_save; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_travel_save (user_id, travel_id) FROM stdin;
1900327840@qq.com	1009991988
1900327840@qq.com	1018710340
1900327840@qq.com	1011208034
1900327840@qq.com	1014187071
1900327840@qq.com	1018205338
1900327840@qq.com	1019560466
\.


--
-- Name: raider_comment_comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.raider_comment_comment_id_seq', 2, true);


--
-- Name: raider_kind_instance_kind_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.raider_kind_instance_kind_id_seq', 2, true);


--
-- Name: raider_stars_req; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.raider_stars_req', 1, false);


--
-- Name: travel_kind_instance_kind_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.travel_kind_instance_kind_id_seq', 2, true);


--
-- Name: raider_comment raider_comment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_comment
    ADD CONSTRAINT raider_comment_pkey PRIMARY KEY (user_id, raider_id, comment_id);


--
-- Name: raider_detail raider_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_detail
    ADD CONSTRAINT raider_detail_pkey PRIMARY KEY (raider_id, raider_step);


--
-- Name: raider_kind_instance raider_kind_instance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_kind_instance
    ADD CONSTRAINT raider_kind_instance_pkey PRIMARY KEY (kind_id);


--
-- Name: raider_kind raider_kind_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_kind
    ADD CONSTRAINT raider_kind_pkey PRIMARY KEY (raider_id, kind_id);


--
-- Name: raider raider_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider
    ADD CONSTRAINT raider_pkey PRIMARY KEY (raider_id);


--
-- Name: travel_image travel_image_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_image
    ADD CONSTRAINT travel_image_pkey PRIMARY KEY (travel_id, image_address);


--
-- Name: travel_kind_instance travel_kind_instance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_kind_instance
    ADD CONSTRAINT travel_kind_instance_pkey PRIMARY KEY (kind_id);


--
-- Name: travel_kind travel_kind_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_kind
    ADD CONSTRAINT travel_kind_pkey PRIMARY KEY (travel_id, kind_id);


--
-- Name: travel_product travel_product_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_product
    ADD CONSTRAINT travel_product_pkey PRIMARY KEY (travel_id);


--
-- Name: travel_raider travel_raider_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_raider
    ADD CONSTRAINT travel_raider_pkey PRIMARY KEY (travel_id, raider_id);


--
-- Name: travel_stoke travel_stoke_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_stoke
    ADD CONSTRAINT travel_stoke_pkey PRIMARY KEY (travel_id, travel_step_id, travel_copy_id);


--
-- Name: user_image user_image_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_image
    ADD CONSTRAINT user_image_pkey PRIMARY KEY (user_id);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (user_id);


--
-- Name: user_raider user_raider_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_raider
    ADD CONSTRAINT user_raider_pkey PRIMARY KEY (user_id, raider_id);


--
-- Name: user_save_raider user_save_raider_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_save_raider
    ADD CONSTRAINT user_save_raider_pkey PRIMARY KEY (user_id, raider_id);


--
-- Name: user_star_raider user_star_raider_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_star_raider
    ADD CONSTRAINT user_star_raider_pkey PRIMARY KEY (user_id, raider_id);


--
-- Name: user_travel_booking user_travel_boking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_travel_booking
    ADD CONSTRAINT user_travel_boking_pkey PRIMARY KEY (user_id, travel_id);


--
-- Name: user_travel_save user_travel_save_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_travel_save
    ADD CONSTRAINT user_travel_save_pkey PRIMARY KEY (user_id, travel_id);


--
-- Name: raider_comment_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX raider_comment_index ON public.raider_comment USING btree (user_id, comment_id, raider_id);


--
-- Name: raider_detail_raider_id_raider_step_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX raider_detail_raider_id_raider_step_idx ON public.raider_detail USING btree (raider_id, raider_step);


--
-- Name: raider_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX raider_index ON public.raider USING btree (raider_id);


--
-- Name: raider_kind_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX raider_kind_index ON public.raider_kind USING btree (raider_id, kind_id);


--
-- Name: travel_image_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX travel_image_index ON public.travel_image USING btree (travel_id, image_address);


--
-- Name: travel_kind_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX travel_kind_index ON public.travel_kind USING btree (travel_id, kind_id);


--
-- Name: travel_product_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX travel_product_index ON public.travel_product USING btree (travel_id);


--
-- Name: travel_raider_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX travel_raider_index ON public.travel_raider USING btree (travel_id, raider_id);


--
-- Name: travel_stoke_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX travel_stoke_index ON public.travel_stoke USING btree (travel_id, travel_step_id);


--
-- Name: user_image_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_image_index ON public.user_image USING btree (user_id);


--
-- Name: user_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_index ON public."user" USING btree (user_id);


--
-- Name: user_raider_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_raider_index ON public.user_raider USING btree (user_id, raider_id);


--
-- Name: user_save_raider_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_save_raider_index ON public.user_save_raider USING btree (user_id, raider_id);


--
-- Name: user_star_raider_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_star_raider_index ON public.user_star_raider USING btree (user_id, raider_id);


--
-- Name: user_travel_boking_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_travel_boking_index ON public.user_travel_booking USING btree (user_id, travel_id);


--
-- Name: user_star_raider add_user_star_raider_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER add_user_star_raider_trigger AFTER INSERT ON public.user_star_raider FOR EACH ROW EXECUTE FUNCTION public.auto_increase_star();


--
-- Name: raider delete_raider; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER delete_raider BEFORE DELETE ON public.raider FOR EACH ROW EXECUTE FUNCTION public.delete_raider();


--
-- Name: travel_product delete_travel_product_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER delete_travel_product_trigger BEFORE DELETE ON public.travel_product FOR EACH ROW EXECUTE FUNCTION public.delete_travel_product();


--
-- Name: user delete_user_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER delete_user_trigger BEFORE DELETE ON public."user" FOR EACH ROW EXECUTE FUNCTION public.delete_user();


--
-- Name: raider_comment raider_comment_raider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_comment
    ADD CONSTRAINT raider_comment_raider_id_fkey FOREIGN KEY (raider_id) REFERENCES public.raider(raider_id);


--
-- Name: raider_comment raider_comment_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_comment
    ADD CONSTRAINT raider_comment_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);


--
-- Name: raider_detail raider_detail_raider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_detail
    ADD CONSTRAINT raider_detail_raider_id_fkey FOREIGN KEY (raider_id) REFERENCES public.raider(raider_id);


--
-- Name: raider_kind raider_kind_kind_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_kind
    ADD CONSTRAINT raider_kind_kind_id_fkey FOREIGN KEY (kind_id) REFERENCES public.raider_kind_instance(kind_id);


--
-- Name: raider_kind raider_kind_raider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raider_kind
    ADD CONSTRAINT raider_kind_raider_id_fkey FOREIGN KEY (raider_id) REFERENCES public.raider(raider_id);


--
-- Name: travel_image travel_image_travel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_image
    ADD CONSTRAINT travel_image_travel_id_fkey FOREIGN KEY (travel_id) REFERENCES public.travel_product(travel_id);


--
-- Name: travel_kind travel_kind_kind_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_kind
    ADD CONSTRAINT travel_kind_kind_id_fkey FOREIGN KEY (kind_id) REFERENCES public.travel_kind_instance(kind_id);


--
-- Name: travel_kind travel_kind_travel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_kind
    ADD CONSTRAINT travel_kind_travel_id_fkey FOREIGN KEY (travel_id) REFERENCES public.travel_product(travel_id);


--
-- Name: travel_raider travel_raider_raider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_raider
    ADD CONSTRAINT travel_raider_raider_id_fkey FOREIGN KEY (raider_id) REFERENCES public.raider(raider_id);


--
-- Name: travel_raider travel_raider_travel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_raider
    ADD CONSTRAINT travel_raider_travel_id_fkey FOREIGN KEY (travel_id) REFERENCES public.travel_product(travel_id);


--
-- Name: travel_stoke travel_stoke_travel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.travel_stoke
    ADD CONSTRAINT travel_stoke_travel_id_fkey FOREIGN KEY (travel_id) REFERENCES public.travel_product(travel_id);


--
-- Name: user_image user_image_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_image
    ADD CONSTRAINT user_image_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);


--
-- Name: user_raider user_raider_raider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_raider
    ADD CONSTRAINT user_raider_raider_id_fkey FOREIGN KEY (raider_id) REFERENCES public.raider(raider_id);


--
-- Name: user_raider user_raider_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_raider
    ADD CONSTRAINT user_raider_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);


--
-- Name: user_save_raider user_save_raider_raider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_save_raider
    ADD CONSTRAINT user_save_raider_raider_id_fkey FOREIGN KEY (raider_id) REFERENCES public.raider(raider_id);


--
-- Name: user_save_raider user_save_raider_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_save_raider
    ADD CONSTRAINT user_save_raider_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);


--
-- Name: user_star_raider user_star_raider_raider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_star_raider
    ADD CONSTRAINT user_star_raider_raider_id_fkey FOREIGN KEY (raider_id) REFERENCES public.raider(raider_id);


--
-- Name: user_star_raider user_star_raider_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_star_raider
    ADD CONSTRAINT user_star_raider_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);


--
-- Name: user_travel_booking user_travel_boking_travel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_travel_booking
    ADD CONSTRAINT user_travel_boking_travel_id_fkey FOREIGN KEY (travel_id) REFERENCES public.travel_product(travel_id);


--
-- Name: user_travel_booking user_travel_boking_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_travel_booking
    ADD CONSTRAINT user_travel_boking_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);


--
-- Name: user_travel_save user_travel_save_travel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_travel_save
    ADD CONSTRAINT user_travel_save_travel_id_fkey FOREIGN KEY (travel_id) REFERENCES public.travel_product(travel_id);


--
-- Name: user_travel_save user_travel_save_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_travel_save
    ADD CONSTRAINT user_travel_save_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(user_id);


--
-- PostgreSQL database dump complete
--

