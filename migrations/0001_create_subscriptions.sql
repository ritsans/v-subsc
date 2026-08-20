CREATE TABLE IF NOT EXISTS subscriptions (
	id TEXT PRIMARY KEY,
	user_id TEXT,
	name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 60),
	price_minor INTEGER NOT NULL CHECK (price_minor > 0),
	currency TEXT NOT NULL CHECK (currency IN ('JPY', 'USD')),
	category_id TEXT NOT NULL,
	next_billing_date TEXT NOT NULL,
	free_trial_days INTEGER NOT NULL DEFAULT 0 CHECK (free_trial_days >= 0),
	created_at TEXT NOT NULL,
	updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS subscriptions_created_at_idx
	ON subscriptions (created_at);

CREATE INDEX IF NOT EXISTS subscriptions_next_billing_date_idx
	ON subscriptions (next_billing_date);
