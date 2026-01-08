SELECT e.text,
    l.lemma,
    el.note
FROM expression_link el
    JOIN expression e ON e.id = el.expression_id
    JOIN lexeme l ON l.id = el.lexeme_id
WHERE e.id = '095d3418-c888-44fd-9b8a-4ec8919545ee';