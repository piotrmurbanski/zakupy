-- AlterTable
ALTER TABLE "list_items" ADD COLUMN "comment" TEXT;

UPDATE "list_items"
SET "comment" = NULLIF(
  TRIM(
    CONCAT_WS(
      ' ',
      CASE
        WHEN "quantity" ~ '^[0-9]+$' THEN NULL
        ELSE "quantity"
      END,
      "unit"
    )
  ),
  ''
);

ALTER TABLE "list_items" ADD COLUMN "quantity_int" INTEGER NOT NULL DEFAULT 1;

UPDATE "list_items"
SET "quantity_int" = CASE
  WHEN "quantity" ~ '^[0-9]+$' AND CAST("quantity" AS INTEGER) > 0 THEN CAST("quantity" AS INTEGER)
  ELSE 1
END;

ALTER TABLE "list_items" DROP COLUMN "quantity";
ALTER TABLE "list_items" DROP COLUMN "unit";
ALTER TABLE "list_items" RENAME COLUMN "quantity_int" TO "quantity";

-- CreateTable
CREATE TABLE "item_suggestions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "normalized_name" TEXT NOT NULL,
    "comment" TEXT,
    "normalized_comment" TEXT NOT NULL DEFAULT '',
    "usage_count" INTEGER NOT NULL DEFAULT 1,
    "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "item_suggestions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "item_suggestions_user_id_normalized_name_normalized_comment_key"
ON "item_suggestions"("user_id", "normalized_name", "normalized_comment");

-- CreateIndex
CREATE INDEX "item_suggestions_user_id_usage_count_last_used_at_idx"
ON "item_suggestions"("user_id", "usage_count", "last_used_at");

-- Backfill current items into suggestions
INSERT INTO "item_suggestions" (
  "id",
  "user_id",
  "name",
  "normalized_name",
  "comment",
  "normalized_comment",
  "usage_count",
  "last_used_at",
  "created_at",
  "updated_at"
)
SELECT
  md5(CONCAT("created_by_user_id", ':', LOWER(BTRIM("name")), ':', COALESCE(LOWER(BTRIM("comment")), ''))),
  "created_by_user_id",
  "name",
  LOWER(BTRIM("name")),
  "comment",
  COALESCE(NULLIF(LOWER(BTRIM("comment")), ''), ''),
  SUM(GREATEST("quantity", 1)),
  MAX("updated_at"),
  MIN("created_at"),
  MAX("updated_at")
FROM "list_items"
GROUP BY
  "created_by_user_id",
  "name",
  LOWER(BTRIM("name")),
  "comment",
  COALESCE(NULLIF(LOWER(BTRIM("comment")), ''), '');

-- AddForeignKey
ALTER TABLE "item_suggestions"
ADD CONSTRAINT "item_suggestions_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
