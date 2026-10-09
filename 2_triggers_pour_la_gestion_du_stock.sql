--Trigger : bloquer la vente si le stock est insuffisant
--======================================================
CREATE OR REPLACE FUNCTION fn_verifier_stock_avant_vente()
RETURNS TRIGGER AS $$
DECLARE
    stock_disponible INT;
BEGIN
    SELECT stock INTO stock_disponible
    FROM article
    WHERE id_article = NEW.id_article
    FOR UPDATE;

    IF stock_disponible < NEW.quantite THEN
        RAISE EXCEPTION 
        'Stock insuffisant (Disponible: %, Demandé: %)',
        stock_disponible, NEW.quantite;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Trigger
--=======
CREATE TRIGGER trg_verifier_stock_avant_vente
BEFORE INSERT ON vente
FOR EACH ROW
EXECUTE FUNCTION fn_verifier_stock_avant_vente();

--Trigger : mise à jour automatique du stock après vente
--======================================================

CREATE OR REPLACE FUNCTION fn_mise_a_jour_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE article
    SET stock = stock - NEW.quantite
    WHERE id_article = NEW.id_article;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Trigger
--=======
CREATE TRIGGER trg_mise_a_jour_stock
AFTER INSERT ON vente
FOR EACH ROW
EXECUTE FUNCTION fn_mise_a_jour_stock();

