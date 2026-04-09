-- AlterTable
ALTER TABLE "shopping_lists"
ADD COLUMN "archived_at" TIMESTAMP(3),
ADD COLUMN "archived_by_user_id" TEXT;

-- CreateIndex
CREATE INDEX "shopping_lists_archived_at_idx" ON "shopping_lists"("archived_at");

-- AddForeignKey
ALTER TABLE "shopping_lists"
ADD CONSTRAINT "shopping_lists_archived_by_user_id_fkey"
FOREIGN KEY ("archived_by_user_id") REFERENCES "users"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
