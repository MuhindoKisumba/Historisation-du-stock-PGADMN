--Table d’historique du stock
--===========================
CREATE TABLE stock_historique (
    id_historique SERIAL PRIMARY KEY,
    id_article INT NOT NULL,
    type_mouvement VARCHAR(20) NOT NULL,
    stock_avant INT NOT NULL,
    quantite INT NOT NULL,
    stock_apres INT NOT NULL,
    reference VARCHAR(100),
    utilisateur VARCHAR(100) DEFAULT current_user,
    date_mouvement TIMESTAMP DEFAULT NOW()
);

--Trigger : historisation automatique après une vente
--===================================================
CREATE OR REPLACE FUNCTION fn_historiser_stock_vente()
RETURNS TRIGGER AS $$
DECLARE
    stock_avant INT;
    stock_apres INT;
BEGIN
    SELECT stock + NEW.quantite INTO stock_avant
    FROM article
    WHERE id_article = NEW.id_article;

    SELECT stock INTO stock_apres
    FROM article
    WHERE id_article = NEW.id_article;

    INSERT INTO stock_historique (
        id_article,
        type_mouvement,
        stock_avant,
        quantite,
        stock_apres,
        reference
    ) VALUES (
        NEW.id_article,
        'VENTE',
        stock_avant,
        NEW.quantite,
        stock_apres,
        'VENTE #' || NEW.id_vente
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Trigger
--=======
CREATE TRIGGER trg_historique_stock_vente
AFTER INSERT ON vente
FOR EACH ROW
EXECUTE FUNCTION fn_historiser_stock_vente();

--Trigger : historisation des entrées de stock (approvisionnement)
--Table d’entrée de stock :
--================================================================
CREATE TABLE entree_stock (
    id_entree SERIAL PRIMARY KEY,
    id_article INT REFERENCES article(id_article),
    quantite INT CHECK (quantite > 0),
    date_entree TIMESTAMP DEFAULT NOW(),
    fournisseur VARCHAR(100)
);

--Fonction
--========
CREATE OR REPLACE FUNCTION fn_historiser_stock_entree()
RETURNS TRIGGER AS $$
DECLARE
    stock_avant INT;
BEGIN
    SELECT stock INTO stock_avant
    FROM article
    WHERE id_article = NEW.id_article;

    UPDATE article
    SET stock = stock + NEW.quantite
    WHERE id_article = NEW.id_article;

    INSERT INTO stock_historique (
        id_article,
        type_mouvement,
        stock_avant,
        quantite,
        stock_apres,
        reference
    ) VALUES (
        NEW.id_article,
        'ENTREE',
        stock_avant,
        NEW.quantite,
        stock_avant + NEW.quantite,
        'ENTREE #' || NEW.id_entree
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Trigger
--=======
CREATE TRIGGER trg_historique_stock_entree
AFTER INSERT ON entree_stock
FOR EACH ROW
EXECUTE FUNCTION fn_historiser_stock_entree();

--Trigger : historisation des corrections manuelles de stock
--==========================================================
CREATE OR REPLACE FUNCTION fn_historiser_correction_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.stock <> NEW.stock THEN
        INSERT INTO stock_historique (
            id_article,
            type_mouvement,
            stock_avant,
            quantite,
            stock_apres,
            reference
        ) VALUES (
            NEW.id_article,
            'CORRECTION',
            OLD.stock,
            NEW.stock - OLD.stock,
            NEW.stock,
            'CORRECTION MANUELLE'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Trigger
--=======
CREATE TRIGGER trg_historique_correction_stock
AFTER UPDATE OF stock ON article
FOR EACH ROW
EXECUTE FUNCTION fn_historiser_correction_stock();

--Trigger : annulation de vente (retour stock + historisation)
--============================================================
CREATE OR REPLACE FUNCTION fn_annulation_vente_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE article
    SET stock = stock + OLD.quantite
    WHERE id_article = OLD.id_article;

    INSERT INTO stock_historique (
        id_article,
        type_mouvement,
        stock_avant,
        quantite,
        stock_apres,
        reference
    ) VALUES (
        OLD.id_article,
        'ANNULATION_VENTE',
        (SELECT stock - OLD.quantite FROM article WHERE id_article = OLD.id_article),
        OLD.quantite,
        (SELECT stock FROM article WHERE id_article = OLD.id_article),
        'ANNULATION VENTE #' || OLD.id_vente
    );

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

--Trigger
--=======
CREATE TRIGGER trg_annulation_vente_stock
AFTER DELETE ON vente
FOR EACH ROW
EXECUTE FUNCTION fn_annulation_vente_stock();

--Exemples de requêtes d’audit
--Historique d’un article
--============================
SELECT *
FROM stock_historique
WHERE id_article = 1
ORDER BY date_mouvement DESC;

