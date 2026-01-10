INSERT INTO source (
        id,
        title,
        author,
        publisher,
        year,
        source_type,
        license_id,
        url,
        notes
    )
VALUES (
        gen_random_uuid(),
        'Kamusi AI Definitions v1',
        'Kamusi Team',
        'Kamusi',
        2026,
        'ai',
        'c1f64f93-0cde-4459-a7e4-cc042f7f1d5a',
        NULL,
        'AI-generated Swahili definitions derived from English glosses; requires human review.'
    )
RETURNING id;