DROP TABLE IF EXISTS material;
DROP TABLE IF EXISTS food;
DROP TABLE IF EXISTS clothes;
DROP TABLE IF EXISTS trading;
DROP TABLE IF EXISTS cargo;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS legs;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS ships_nationalities;
DROP TABLE IF EXISTS ships;
DROP TABLE IF EXISTS ports;
DROP TABLE IF EXISTS diplomatic_relationships;
DROP TABLE IF EXISTS countries;



CREATE TABLE cargo (
    cargo_id int4 NOT NULL,
    shipment_id int4,
    product_id int4,
    quantity int4 NOT NULL,
    PRIMARY KEY (cargo_id)
);

CREATE TABLE clothes (
    product_id int4 NOT NULL,
    material text NOT NULL,
    unit_price int4 NOT NULL,
    unit_weight float8 NOT NULL,
    PRIMARY KEY (product_id)
);

CREATE TABLE countries (
    country_name text NOT NULL,
    continent text NOT NULL,
    PRIMARY KEY (country_name)
);

CREATE TABLE diplomatic_relationships (
    country_name_1 text NOT NULL,
    country_name_2 text NOT NULL,
    type text NOT NULL,
    PRIMARY KEY (country_name_1, country_name_2)
);

CREATE TABLE food (
    product_id int4 NOT NULL,
    shelf_life int4 NOT NULL,
    price_per_kg int4 NOT NULL,
    PRIMARY KEY (product_id)
);

CREATE TABLE legs (
    shipment_id int4 NOT NULL,
    port_name text NOT NULL,
    port_country_name text NOT NULL,
    offloaded_passengers int4 NOT NULL,
    loaded_passengers int4 NOT NULL,
    traveled_distance int4 NOT NULL,
    PRIMARY KEY (shipment_id, port_name, port_country_name)
);

CREATE TABLE material (
    product_id int4 NOT NULL,
    volume_price int4 NOT NULL,
    PRIMARY KEY (product_id)
);

CREATE TABLE ports (
    port_name text NOT NULL,
    port_country_name text NOT NULL,
    latitude float8 NOT NULL,
    longitude float8 NOT NULL,
    port_category int4 NOT NULL,
    PRIMARY KEY (port_name, port_country_name)
);

CREATE TABLE products (
    product_id int4 NOT NULL,
    name text NOT NULL,
    volume int4 NOT NULL,
    perishable bool NOT NULL,
    categorized bool NOT NULL DEFAULT FALSE,
    PRIMARY KEY (product_id)
);

CREATE TABLE shipments (
    shipment_id int4 NOT NULL,
    ship_id int4,
    port_name_start text,
    port_name_end text,
    port_country_name_start text,
    port_country_name_end text,
    start_date date NOT NULL,
    end_date date,
    duration int4,
    passengers int4 NOT NULL,
    shipment_type text NOT NULL,
    class text NOT NULL,
    capture_date date,
    distance int4 NOT NULL,
    departed bool NOT NULL DEFAULT FALSE,
    PRIMARY KEY (shipment_id)
);

CREATE TABLE ships (
    ship_id int4 NOT NULL,
    type text NOT NULL,
    ship_category int4 NOT NULL,
    tonnage_capacity int4 NOT NULL,
    passengers_capacity int4 NOT NULL,
    PRIMARY KEY (ship_id)
);

CREATE TABLE ships_nationalities (
    ship_id int4 NOT NULL,
    country_name text NOT NULL,
    start_possesion_date date NOT NULL,
    PRIMARY KEY (ship_id, country_name, start_possesion_date)
);

CREATE TABLE trading (
    cargo_id int4 NOT NULL,
    shipment_id int4 NOT NULL,
    port_name text NOT NULL,
    port_country_name text NOT NULL,
    sold int4 NOT NULL,
    bought int4 NOT NULL,
    PRIMARY KEY (cargo_id, shipment_id, port_name, port_country_name)
);

ALTER TABLE cargo ADD FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE cargo ADD FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id);
ALTER TABLE clothes ADD FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE diplomatic_relationships ADD FOREIGN KEY (country_name_1) REFERENCES countries(country_name);
ALTER TABLE diplomatic_relationships ADD FOREIGN KEY (country_name_1) REFERENCES countries(country_name);
ALTER TABLE food ADD FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE legs ADD FOREIGN KEY (port_name, port_country_name) REFERENCES ports(port_name, port_country_name);
ALTER TABLE legs ADD FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id);
ALTER TABLE material ADD FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE ports ADD FOREIGN KEY (port_country_name) REFERENCES countries(country_name);
ALTER TABLE shipments ADD FOREIGN KEY (port_name_start, port_country_name_start) REFERENCES ports(port_name, port_country_name);
ALTER TABLE shipments ADD FOREIGN KEY (port_name_end, port_country_name_end) REFERENCES ports(port_name, port_country_name);
ALTER TABLE shipments ADD FOREIGN KEY (ship_id) REFERENCES ships(ship_id);
ALTER TABLE ships_nationalities ADD FOREIGN KEY (country_name) REFERENCES countries(country_name);
ALTER TABLE ships_nationalities ADD FOREIGN KEY (ship_id) REFERENCES ships(ship_id);
ALTER TABLE trading ADD FOREIGN KEY (port_name, port_country_name) REFERENCES ports(port_name, port_country_name);
ALTER TABLE trading ADD FOREIGN KEY (cargo_id) REFERENCES cargo(cargo_id);
ALTER TABLE trading ADD FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id);

CREATE OR REPLACE FUNCTION departure_mismatches()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT
            COUNT(*)
        FROM
            ships
        NATURAL JOIN (
            SELECT
                shipment_id,
                ship_id,
                passengers,
                SUM(A.volume_cargo) AS volume_shipment
            FROM
                shipments
                NATURAL
                LEFT OUTER JOIN (
                    SELECT
                        shipment_id,
                        cargo_id,
                        quantity * volume AS volume_cargo
                    FROM
                        cargo
                        NATURAL JOIN products) AS A
                GROUP BY
                    shipment_id,
                    ship_id,
                    passengers) AS B
            WHERE
                B.passengers <> passengers_capacity
                AND B.volume_shipment <> tonnage_capacity);
END;
$function$;

ALTER TABLE shipments ADD CONSTRAINT check_departure CHECK (departed = FALSE OR departure_mismatches() = 0);


CREATE OR REPLACE FUNCTION categorized_total()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT
            COUNT(*)
        FROM
            products as P
        WHERE NOT EXISTS (SELECT *
                         FROM food as F,clothes as C,material as M
                         WHERE P.product_id = F.product_id
                         OR P.product_id = C.product_id
                         OR P.product_id = M.product_id));
END;
$function$;

ALTER TABLE products ADD CONSTRAINT check_total CHECK (categorized = FALSE OR categorized_total() = 0);


CREATE OR REPLACE FUNCTION categorized_disjointed()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT
            COUNT(*)
        FROM ((SELECT F.product_id
        	 FROM food as F,clothes as C
        	 WHERE F.product_id = C.product_id
             UNION
             SELECT F.product_id
        	 FROM food as F,material as M
        	 WHERE F.product_id = M.product_id)
             UNION
             SELECT C.product_id
        	 FROM clothes as C,material as M
        	 WHERE C.product_id = M.product_id) as FCM);
END;
$function$;

ALTER TABLE products ADD CONSTRAINT check_disjointed CHECK (categorized = FALSE OR categorized_disjointed() = 0);


CREATE OR REPLACE FUNCTION category_mismatches_shipment()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT
             COUNT(*)
        FROM
            (SELECT *
            FROM(SELECT *
                 FROM shipments
                 NATURAL JOIN ships) as S
            JOIN ports
            ON port_name = S.port_name_start
            AND port_country_name = S.port_country_name_start
            WHERE ship_category > port_category
            UNION
            SELECT *
            FROM(SELECT *
                 FROM shipments
                 NATURAL JOIN ships) as S
            JOIN ports
            ON port_name = S.port_name_end
            AND port_country_name = S.port_country_name_end
            WHERE ship_category > port_category) as C);
END;
$function$;

ALTER TABLE shipments ADD CONSTRAINT check_category CHECK (category_mismatches_shipment() = 0);


CREATE OR REPLACE FUNCTION category_mismatches_trading()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT
             COUNT(*)
        FROM(SELECT *
             FROM shipments
             NATURAL JOIN ships) as S
        JOIN(SELECT *
             FROM ports
             NATURAL JOIN trading) as S1
        ON S1.shipment_id = S.shipment_id
        WHERE ship_category > port_category);
END;
$function$;

ALTER TABLE trading ADD CONSTRAINT check_category CHECK (category_mismatches_trading() = 0);

\i 'load.sql';