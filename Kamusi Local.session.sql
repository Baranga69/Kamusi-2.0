SELECT review_status,
    count(*)
FROM sense_definition
WHERE lang_code = 'sw'
    AND is_ai_generated = true
GROUP BY review_status
ORDER BY count(*) DESC;