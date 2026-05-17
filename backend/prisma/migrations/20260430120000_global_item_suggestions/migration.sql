CREATE TABLE "item_suggestions_new" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "normalized_name" TEXT NOT NULL,
    "comment" TEXT,
    "normalized_comment" TEXT NOT NULL DEFAULT '',
    "icon_key" TEXT NOT NULL DEFAULT 'default',
    "usage_count" INTEGER NOT NULL DEFAULT 1,
    "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "item_suggestions_new_pkey" PRIMARY KEY ("id")
);

INSERT INTO "item_suggestions_new" (
  "id",
  "name",
  "normalized_name",
  "comment",
  "normalized_comment",
  "icon_key",
  "usage_count",
  "last_used_at",
  "created_at",
  "updated_at"
)
SELECT
  md5(CONCAT(chosen."normalized_name", ':', chosen."normalized_comment")),
  chosen."name",
  chosen."normalized_name",
  chosen."comment",
  chosen."normalized_comment",
  chosen."icon_key",
  totals."usage_count",
  totals."last_used_at",
  totals."created_at",
  totals."updated_at"
FROM (
  SELECT
    "normalized_name",
    "normalized_comment",
    SUM("usage_count") AS "usage_count",
    MAX("last_used_at") AS "last_used_at",
    MIN("created_at") AS "created_at",
    MAX("updated_at") AS "updated_at"
  FROM "item_suggestions"
  GROUP BY "normalized_name", "normalized_comment"
) AS totals
JOIN (
  SELECT DISTINCT ON ("normalized_name", "normalized_comment")
    "normalized_name",
    "normalized_comment",
    "name",
    "comment",
    "icon_key"
  FROM "item_suggestions"
  ORDER BY "normalized_name", "normalized_comment", "last_used_at" DESC, "updated_at" DESC, "created_at" DESC
) AS chosen
  ON chosen."normalized_name" = totals."normalized_name"
 AND chosen."normalized_comment" = totals."normalized_comment";

DROP TABLE "item_suggestions";

ALTER TABLE "item_suggestions_new" RENAME TO "item_suggestions";

CREATE UNIQUE INDEX "item_suggestions_normalized_name_normalized_comment_key"
ON "item_suggestions"("normalized_name", "normalized_comment");

CREATE INDEX "item_suggestions_usage_count_last_used_at_idx"
ON "item_suggestions"("usage_count", "last_used_at");
