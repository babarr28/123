#!/usr/bin/env bash
# bootstrap_zetsu_ai.sh — Recrée le starter SaaS "Zetsu AI" complet en local
# Usage: chmod +x bootstrap_zetsu_ai.sh && ./bootstrap_zetsu_ai.sh

set -euo pipefail

ROOT="zetsu-ai"
rm -rf "$ROOT"
mkdir -p "$ROOT"
cd "$ROOT"

# helpers
w() { mkdir -p "$(dirname "$1")"; cat > "$1" <<'EOF'
'"$2"'
EOF
}

# =========================
# package.json
# =========================
cat > package.json <<'EOF'
{
  "name": "zetsu-ai",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000",
    "lint": "eslint .",
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev",
    "db:seed": "tsx scripts/seed.ts",
    "format": "prettier --write .",
    "worker": "tsx src/queue/workers/agentRunner.ts",
    "cron": "tsx src/queue/workers/cronDigest.ts",
    "test": "vitest run"
  },
  "dependencies": {
    "@aws-sdk/client-s3": "^3.645.0",
    "@hookform/resolvers": "^3.9.0",
    "@next-auth/prisma-adapter": "^1.0.7",
    "@sentry/nextjs": "^8.20.0",
    "@tanstack/react-query": "^5.51.1",
    "@trpc/client": "^11.0.0-rc.472",
    "@trpc/react-query": "^11.0.0-rc.472",
    "@trpc/server": "^11.0.0-rc.472",
    "autoprefixer": "^10.4.20",
    "bullmq": "^5.33.2",
    "cheerio": "^1.0.0",
    "clsx": "^2.1.1",
    "framer-motion": "^11.3.30",
    "ioredis": "^5.4.1",
    "lucide-react": "^0.454.0",
    "next": "14.2.5",
    "next-auth": "^4.24.8",
    "next-intl": "^3.18.1",
    "openai": "^4.56.0",
    "pino": "^9.5.0",
    "pino-pretty": "^11.2.2",
    "postcss": "^8.4.45",
    "posthog-js": "^1.198.2",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "react-flow-renderer": "^10.3.18",
    "react-hook-form": "^7.53.0",
    "resend": "^3.5.0",
    "stripe": "^16.8.0",
    "tailwind-merge": "^2.5.2",
    "tailwindcss": "^3.4.10",
    "zod": "^3.23.8",
    "@anthropic-ai/sdk": "^0.27.3"
  },
  "devDependencies": {
    "@types/node": "^22.5.5",
    "@types/react": "^18.3.5",
    "@types/react-dom": "^18.3.0",
    "eslint": "^9.10.0",
    "eslint-config-next": "14.2.5",
    "playwright": "^1.47.2",
    "prettier": "^3.3.3",
    "prisma": "^5.20.0",
    "tsx": "^4.19.2",
    "typescript": "^5.6.2",
    "vitest": "^2.0.5"
  }
}
EOF

# =========================
# tsconfig.json
# =========================
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowJs": false,
    "strict": true,
    "noImplicitAny": true,
    "noUncheckedIndexedAccess": true,
    "skipLibCheck": true,
    "noEmit": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "incremental": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", "scripts/*.ts"],
  "exclude": ["node_modules"]
}
EOF

# =========================
# next config + lint + prettier
# =========================
cat > next.config.mjs <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: { typedRoutes: true },
  reactStrictMode: true,
  images: { remotePatterns: [] },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" }
        ]
      }
    ]
  }
};
export default nextConfig;
EOF

cat > .eslintrc.cjs <<'EOF'
module.exports = {
  root: true,
  extends: ["next", "next/core-web-vitals"],
  rules: {}
}
EOF

cat > .prettierrc <<'EOF'
{
  "semi": true,
  "singleQuote": false,
  "trailingComma": "all",
  "printWidth": 100
}
EOF

# =========================
# Tailwind & styles
# =========================
cat > postcss.config.mjs <<'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

mkdir -p src/styles
cat > tailwind.config.ts <<'EOF'
import type { Config } from "tailwindcss";

export default {
  darkMode: ["class"],
  content: [
    "./src/app/**/*.{ts,tsx}",
    "./src/components/**/*.{ts,tsx}",
    "./src/lib/**/*.{ts,tsx}"
  ],
  theme: { extend: {} },
  plugins: []
} satisfies Config;
EOF

cat > src/styles/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root{color-scheme:light dark}
EOF

# =========================
# .env.example
# =========================
cat > .env.example <<'EOF'
APP_URL=http://localhost:3000

DATABASE_URL=postgresql://postgres:postgres@postgres:5432/zetsu?schema=public
REDIS_URL=redis://redis:6379
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=zetsu

NEXTAUTH_SECRET=changeme
NEXTAUTH_URL=http://localhost:3000

EMAIL_SERVER_HOST=mailpit
EMAIL_SERVER_USER=test
EMAIL_SERVER_PASSWORD=test

STRIPE_SECRET_KEY=sk_test_123
STRIPE_WEBHOOK_SECRET=whsec_123
STRIPE_PRICE_IDS_JSON={"free":"price_free","starter":"price_starter","pro":"price_pro"}

SENTRY_DSN=
POSTHOG_KEY=
POSTHOG_HOST=

OPENAI_API_KEY=
ANTHROPIC_API_KEY=
GOOGLE_API_KEY=

WHATSAPP_CLOUD_TOKEN=
WHATSAPP_PHONE_ID=
TELEGRAM_BOT_TOKEN=

GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
EOF

# =========================
# Docker & compose
# =========================
cat > Dockerfile <<'EOF'
# Multi-stage build for Next.js app
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* .npmrc* ./
RUN npm ci || yarn || pnpm i

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma
CMD ["npm","start"]
EOF

cat > docker-compose.yml <<'EOF'
version: "3.9"
services:
  web:
    build: .
    container_name: zetsu-web
    env_file: .env.example
    environment:
      - APP_URL=http://localhost:3000
    ports:
      - "3000:3000"
    depends_on:
      - postgres
      - redis
      - minio
      - mailpit

  worker:
    build: .
    command: ["npm","run","worker"]
    container_name: zetsu-worker
    env_file: .env.example
    depends_on:
      - redis
      - postgres

  cron:
    build: .
    command: ["npm","run","cron"]
    container_name: zetsu-cron
    env_file: .env.example
    depends_on:
      - redis
      - postgres

  postgres:
    image: ankane/pgvector:latest
    container_name: zetsu-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: zetsu
    ports: ["5432:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: zetsu-redis
    ports: ["6379:6379"]

  minio:
    image: minio/minio:latest
    container_name: zetsu-minio
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data --console-address ":9001"
    ports: ["9000:9000", "9001:9001"]
    volumes:
      - minio:/data

  mailpit:
    image: axllent/mailpit:latest
    container_name: zetsu-mailpit
    ports: ["8025:8025","1025:1025"]

volumes:
  pgdata:
  minio:
EOF

cat > .dockerignore <<'EOF'
node_modules
.next
.git
.gitignore
Dockerfile*
docker-compose.yml
.env*
npm-debug.log
pnpm-lock.yaml
yarn.lock
EOF

# =========================
# Prisma schema (pgvector)
# =========================
mkdir -p prisma
cat > prisma/schema.prisma <<'EOF'
generator client { provider = "prisma-client-js" }

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id            String   @id @default(cuid())
  email         String?  @unique
  name          String?
  image         String?
  accounts      Account[]
  sessions      Session[]
  memberships   Membership[]
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  auditLogs     AuditLog[] @relation("UserAudit")
}

model Account {
  id                 String  @id @default(cuid())
  userId             String
  user               User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  type               String
  provider           String
  providerAccountId  String
  refresh_token      String?
  access_token       String?
  expires_at         Int?
  token_type         String?
  scope              String?
  id_token           String?
  session_state      String?
  createdAt          DateTime @default(now())
  updatedAt          DateTime @updatedAt

  @@unique([provider, providerAccountId])
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  expires      DateTime
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}

model Organisation {
  id            String        @id @default(cuid())
  name          String
  createdAt     DateTime      @default(now())
  updatedAt     DateTime      @updatedAt
  memberships   Membership[]
  agents        Agent[]
  runs          Run[]
  toolCreds     ToolCredential[]
  datasets      Dataset[]
  integrations  Integration[]
  apiKeys       ApiKey[]
  webhooks      Webhook[]
  auditLogs     AuditLog[]
  subscription  Subscription?
}

model Membership {
  id        String  @id @default(cuid())
  orgId     String
  userId    String
  role      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  org       Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
  user      User         @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([orgId, userId])
}

model Agent {
  id        String   @id @default(cuid())
  orgId     String
  name      String
  graph     Json
  status    String   @default("draft")
  version   Int      @default(1)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  org       Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
  runs      Run[]
}

model Run {
  id         String   @id @default(cuid())
  agentId    String
  orgId      String
  state      String   @default("queued")
  tokensIn   Int      @default(0)
  tokensOut  Int      @default(0)
  cost       Float    @default(0)
  startedAt  DateTime @default(now())
  finishedAt DateTime?
  logs       Json?
  agent      Agent        @relation(fields: [agentId], references: [id], onDelete: Cascade)
  org        Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
}

model ToolCredential {
  id              String   @id @default(cuid())
  orgId           String
  provider        String
  encryptedSecret String
  scopes          String
  createdAt       DateTime @default(now())
  org             Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
}

model Dataset {
  id        String   @id @default(cuid())
  orgId     String
  name      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  org       Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
  documents Document[]
}

model Document {
  id        String   @id @default(cuid())
  datasetId String
  path      String
  size      Int
  status    String   @default("pending")
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  dataset   Dataset  @relation(fields: [datasetId], references: [id], onDelete: Cascade)
  chunks    VectorChunk[]
}

model VectorChunk {
  id         String   @id @default(cuid())
  documentId String
  content    String
  embedding  Unsupported("vector(1536)")
  meta       Json
  document   Document @relation(fields: [documentId], references: [id], onDelete: Cascade)

  @@index([documentId])
}

model Integration {
  id        String   @id @default(cuid())
  orgId     String
  type      String
  status    String   @default("disconnected")
  settings  Json?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  org       Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
}

model ApiKey {
  id          String   @id @default(cuid())
  orgId       String
  hash        String   @unique
  lastUsedAt  DateTime?
  scopes      String
  ipAllowlist Json?
  createdAt   DateTime @default(now())
  org         Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
}

model Webhook {
  id        String   @id @default(cuid())
  orgId     String
  url       String
  secret    String
  events    Json
  createdAt DateTime @default(now())
  org       Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
}

model AuditLog {
  id          String   @id @default(cuid())
  orgId       String
  actorUserId String?
  action      String
  targetType  String
  targetId    String?
  ip          String?
  createdAt   DateTime @default(now())
  org         Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
  actor       User?        @relation("UserAudit", fields: [actorUserId], references: [id])
}

model Subscription {
  orgId            String   @id
  stripeCustomerId String
  stripeSubId      String
  plan             String
  limits           Json
  org              Organisation @relation(fields: [orgId], references: [id], onDelete: Cascade)
}
EOF

# =========================
# Prisma client helper
# =========================
mkdir -p src/server
cat > src/server/db.ts <<'EOF'
import { PrismaClient } from "@prisma/client";

declare global { var prisma: PrismaClient | undefined; }

export const prisma = global.prisma || new PrismaClient();
if (process.env.NODE_ENV !== "production") global.prisma = prisma;
EOF

# =========================
# Env validation
# =========================
mkdir -p src/lib
cat > src/lib/env.ts <<'EOF'
import { z } from "zod";

const envSchema = z.object({
  APP_URL: z.string().url(),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string(),
  S3_ENDPOINT: z.string().url(),
  S3_ACCESS_KEY: z.string(),
  S3_SECRET_KEY: z.string(),
  S3_BUCKET: z.string(),
  NEXTAUTH_SECRET: z.string(),
  NEXTAUTH_URL: z.string().url(),
  EMAIL_SERVER_HOST: z.string(),
  EMAIL_SERVER_USER: z.string(),
  EMAIL_SERVER_PASSWORD: z.string(),
  STRIPE_SECRET_KEY: z.string().optional(),
  STRIPE_WEBHOOK_SECRET: z.string().optional(),
  STRIPE_PRICE_IDS_JSON: z.string().optional(),
  SENTRY_DSN: z.string().optional(),
  POSTHOG_KEY: z.string().optional(),
  POSTHOG_HOST: z.string().optional(),
  OPENAI_API_KEY: z.string().optional(),
  ANTHROPIC_API_KEY: z.string().optional(),
  GOOGLE_API_KEY: z.string().optional(),
  WHATSAPP_CLOUD_TOKEN: z.string().optional(),
  WHATSAPP_PHONE_ID: z.string().optional(),
  TELEGRAM_BOT_TOKEN: z.string().optional(),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
});

export const env = envSchema.parse(process.env);
EOF

# =========================
# Auth (NextAuth)
# =========================
mkdir -p src/server/auth src/app/api/auth/[...nextauth]
cat > src/server/auth/auth.ts <<'EOF'
import NextAuth, { type NextAuthConfig } from "next-auth";
import EmailProvider from "next-auth/providers/email";
import GoogleProvider from "next-auth/providers/google";
import { PrismaAdapter } from "@next-auth/prisma-adapter";
import { prisma } from "../db";
import nodemailer from "nodemailer";

const emailTransport = nodemailer.createTransport({
  host: process.env.EMAIL_SERVER_HOST,
  port: 1025,
  auth: {
    user: process.env.EMAIL_SERVER_USER,
    pass: process.env.EMAIL_SERVER_PASSWORD,
  },
});

export const authConfig = {
  adapter: PrismaAdapter(prisma),
  session: { strategy: "database" },
  providers: [
    EmailProvider({
      sendVerificationRequest: async ({ identifier, url }) => {
        await emailTransport.sendMail({
          to: identifier,
          from: "login@zetsu.local",
          subject: "Votre lien de connexion",
          text: `Connectez-vous: ${url}`,
        });
      },
    }),
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID ?? "",
      clientSecret: process.env.GOOGLE_CLIENT_SECRET ?? "",
    }),
  ],
  callbacks: {
    async session({ session, user }) {
      if (session.user) (session.user as any).id = user.id;
      return session;
    },
  },
} satisfies NextAuthConfig;

export const { handlers, auth } = NextAuth(authConfig);
EOF

cat > src/app/api/auth/[...nextauth]/route.ts <<'EOF'
export { handlers as GET, handlers as POST } from "@/server/auth/auth";
EOF

# =========================
# tRPC setup
# =========================
mkdir -p src/server/trpc/routers src/app/api/trpc/[trpc]
cat > src/server/trpc/context.ts <<'EOF'
import { auth } from "@/server/auth/auth";
import { prisma } from "@/server/db";
import { env } from "@/lib/env";

export async function createContext() {
  const session = await auth();
  return { session, prisma, env };
}
export type Context = Awaited<ReturnType<typeof createContext>>;
EOF

cat > src/server/trpc/trpc.ts <<'EOF'
import { initTRPC, TRPCError } from "@trpc/server";
import superjson from "superjson";
import { type Context } from "./context";

const t = initTRPC.context<Context>().create({ transformer: superjson });

export const router = t.router;
export const publicProcedure = t.procedure;
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.session?.user) throw new TRPCError({ code: "UNAUTHORIZED" });
  return next();
});
EOF

cat > src/app/api/trpc/[trpc]/route.ts <<'EOF'
import { fetchRequestHandler } from "@trpc/server/adapters/fetch";
import { appRouter } from "@/server/trpc/routers";
import { createContext } from "@/server/trpc/context";

const handler = (req: Request) => {
  return fetchRequestHandler({
    endpoint: "/api/trpc",
    req,
    router: appRouter,
    createContext,
  });
};
export { handler as GET, handler as POST };
EOF

# Routers
cat > src/server/trpc/routers/auth.ts <<'EOF'
import { router, protectedProcedure } from "../trpc";

export const authRouter = router({
  me: protectedProcedure.query(({ ctx }) => ctx.session?.user),
});
EOF

cat > src/server/trpc/routers/orgs.ts <<'EOF'
import { z } from "zod";
import { router, protectedProcedure } from "../trpc";

export const orgsRouter = router({
  list: protectedProcedure.query(async ({ ctx }) => {
    const userId = ctx.session!.user!.id as string;
    return ctx.prisma.membership.findMany({ where: { userId }, include: { org: true } });
  }),
  create: protectedProcedure.input(z.object({ name: z.string().min(2) })).mutation(async ({ ctx, input }) => {
    const userId = ctx.session!.user!.id as string;
    const org = await ctx.prisma.organisation.create({ data: { name: input.name } });
    await ctx.prisma.membership.create({ data: { orgId: org.id, userId, role: "Owner" } });
    return org;
  }),
});
EOF

cat > src/server/trpc/routers/agents.ts <<'EOF'
import { z } from "zod";
import { router, protectedProcedure } from "../trpc";

export const agentsRouter = router({
  list: protectedProcedure.query(async ({ ctx }) => {
    const orgId = (await ctx.prisma.membership.findFirst({
      where: { userId: ctx.session!.user!.id as string },
      select: { orgId: true },
    }))?.orgId;
    return ctx.prisma.agent.findMany({ where: { orgId: orgId ?? "" } });
  }),
  create: protectedProcedure.input(z.object({
    name: z.string().min(2),
    graph: z.any(),
  })).mutation(async ({ ctx, input }) => {
    const orgId = (await ctx.prisma.membership.findFirst({
      where: { userId: ctx.session!.user!.id as string },
      select: { orgId: true },
    }))?.orgId!;
    return ctx.prisma.agent.create({ data: { name: input.name, graph: input.graph, orgId } });
  }),
  run: protectedProcedure.input(z.object({ agentId: z.string() })).mutation(async ({ ctx, input }) => {
    const { agentRunnerQueue } = await import("@/src/queue");
    await agentRunnerQueue.add("run", { agentId: input.agentId, userId: ctx.session!.user!.id });
    return { queued: true };
  }),
});
EOF

cat > src/server/trpc/routers/runs.ts <<'EOF'
import { z } from "zod";
import { router, protectedProcedure } from "../trpc";

export const runsRouter = router({
  list: protectedProcedure.input(z.object({ agentId: z.string().optional() }).optional()).query(async ({ ctx, input }) => {
    const orgId = (await ctx.prisma.membership.findFirst({
      where: { userId: ctx.session!.user!.id as string },
      select: { orgId: true },
    }))?.orgId!;
    return ctx.prisma.run.findMany({
      where: { orgId, ...(input?.agentId ? { agentId: input.agentId } : {}) },
      orderBy: { startedAt: "desc" },
      take: 50,
    });
  })
});
EOF

cat > src/server/trpc/routers/datasets.ts <<'EOF'
import { router, protectedProcedure } from "../trpc";

export const datasetsRouter = router({
  list: protectedProcedure.query(async ({ ctx }) => {
    const orgId = (await ctx.prisma.membership.findFirst({
      where: { userId: ctx.session!.user!.id as string },
      select: { orgId: true },
    }))?.orgId!;
    return ctx.prisma.dataset.findMany({ where: { orgId } });
  }),
});
EOF

cat > src/server/trpc/routers/billing.ts <<'EOF'
import { router, publicProcedure } from "../trpc";

export const billingRouter = router({
  getPlans: publicProcedure.query(() => ([
    { id: "free", name: "Free", price: 0, features: ["1 agent", "100 runs/mois"] },
    { id: "starter", name: "Starter", price: 29, features: ["3 agents", "2000 runs"] },
    { id: "pro", name: "Pro", price: 99, features: ["10 agents", "10000 runs"] }
  ])),
});
EOF

cat > src/server/trpc/routers/admin.ts <<'EOF'
import { router, protectedProcedure } from "../trpc";

export const adminRouter = router({
  systemHealth: protectedProcedure.query(async ({ ctx }) => {
    const users = await ctx.prisma.user.count();
    return { ok: true, users };
  }),
});
EOF

cat > src/server/trpc/routers/index.ts <<'EOF'
import { router } from "../trpc";
import { authRouter } from "./auth";
import { orgsRouter } from "./orgs";
import { agentsRouter } from "./agents";
import { runsRouter } from "./runs";
import { datasetsRouter } from "./datasets";
import { billingRouter } from "./billing";
import { adminRouter } from "./admin";

export const appRouter = router({
  auth: authRouter,
  orgs: orgsRouter,
  agents: agentsRouter,
  runs: runsRouter,
  datasets: datasetsRouter,
  billing: billingRouter,
  admin: adminRouter,
});

export type AppRouter = typeof appRouter;
EOF

# =========================
# Queues & workers
# =========================
mkdir -p src/queue/workers
cat > src/queue/index.ts <<'EOF'
import { Queue } from "bullmq";
import IORedis from "ioredis";
import { env } from "@/lib/env";

const connection = new IORedis(env.REDIS_URL);
export const agentRunnerQueue = new Queue("agentRunner", { connection });
export const cronDigestQueue = new Queue("cronDigest", { connection });
EOF

cat > src/queue/workers/agentRunner.ts <<'EOF'
import { Worker, Job } from "bullmq";
import IORedis from "ioredis";
import { env } from "@/lib/env";
import { prisma } from "@/server/db";
import { runAgent } from "@/src/lib/agents/runtime";

const connection = new IORedis(env.REDIS_URL);

async function processor(job: Job) {
  const { agentId, userId } = job.data as { agentId: string; userId: string };
  const agent = await prisma.agent.findUnique({ where: { id: agentId } });
  if (!agent) throw new Error("Agent not found");
  const orgId = (await prisma.membership.findFirst({ where: { userId }, select: { orgId: true } }))?.orgId!;

  const run = await prisma.run.create({ data: { agentId, orgId, state: "running", tokensIn: 0, tokensOut: 0, cost: 0 } });
  try {
    await runAgent({ agent, runId: run.id });
    await prisma.run.update({ where: { id: run.id }, data: { state: "succeeded", finishedAt: new Date() } });
  } catch (e: any) {
    await prisma.run.update({ where: { id: run.id }, data: { state: "failed", finishedAt: new Date(), logs: { error: String(e?.message ?? e) } } });
    throw e;
  }
}

new Worker("agentRunner", processor, { connection });
console.log("agentRunner worker started");
EOF

cat > src/queue/workers/cronDigest.ts <<'EOF'
import { Worker } from "bullmq";
import IORedis from "ioredis";
import { env } from "@/lib/env";
import { prisma } from "@/server/db";
import { Resend } from "resend";

const connection = new IORedis(env.REDIS_URL);
const resend = new Resend(process.env.RESEND_API_KEY ?? "");

new Worker("cronDigest", async () => {
  const orgs = await prisma.organisation.findMany({ take: 10 });
  for (const org of orgs) {
    const owner = await prisma.membership.findFirst({ where: { orgId: org.id, role: "Owner" }, include: { user: true } });
    if (owner?.user?.email) {
      await resend.emails.send({
        from: "digest@zetsu.local",
        to: owner.user.email,
        subject: "Résumé horaire Zetsu AI",
        text: `Bonjour, votre organisation ${org.name} tourne. Visitez ${process.env.APP_URL}.`,
      });
    }
  }
}, { connection });

console.log("cronDigest worker started");
EOF

# =========================
# LLM & RAG
# =========================
mkdir -p src/lib/llm src/lib/rag src/lib/agents
cat > src/lib/llm/index.ts <<'EOF'
export type ChatMessage = { role: "system" | "user" | "assistant"; content: string };

export interface LLMProvider {
  chat(messages: ChatMessage[], opts?: { model?: string; temperature?: number }): Promise<string>;
  embed(texts: string[], opts?: { model?: string }): Promise<number[][]>;
}

export async function getProvider(): Promise<LLMProvider> {
  const { default: OpenAIProvider } = await import("./openai");
  return new OpenAIProvider();
}
EOF

cat > src/lib/llm/openai.ts <<'EOF'
import OpenAI from "openai";
import type { LLMProvider, ChatMessage } from "./index";

export default class OpenAIProvider implements LLMProvider {
  client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  async chat(messages: ChatMessage[], opts?: { model?: string; temperature?: number }) {
    const res = await this.client.chat.completions.create({
      model: opts?.model ?? "gpt-4o-mini",
      messages,
      temperature: opts?.temperature ?? 0.2,
    } as any);
    return res.choices[0]?.message?.content ?? "";
  }
  async embed(texts: string[], opts?: { model?: string }) {
    const res = await this.client.embeddings.create({
      model: opts?.model ?? "text-embedding-3-small",
      input: texts,
    });
    return res.data.map(v => v.embedding as number[]);
  }
}
EOF

cat > src/lib/rag/chunk.ts <<'EOF'
export function chunkText(text: string, max = 800) {
  const sentences = text.split(/(?<=[.!?])\s+/);
  const chunks: string[] = [];
  let cur = "";
  for (const s of sentences) {
    if ((cur + " " + s).length > max) {
      if (cur) chunks.push(cur.trim());
      cur = s;
    } else {
      cur += " " + s;
    }
  }
  if (cur.trim()) chunks.push(cur.trim());
  return chunks;
}
EOF

cat > src/lib/rag/embed.ts <<'EOF'
import { getProvider } from "@/lib/llm";

export async function embedChunks(chunks: string[]) {
  const prov = await getProvider();
  return prov.embed(chunks);
}
EOF

cat > src/lib/rag/search.ts <<'EOF'
import { prisma } from "@/server/db";

export async function searchSimilar(datasetId: string, embedding: number[], limit = 5) {
  // NOTE: Adapter avec l'opérateur natif pgvector (<=>) selon votre version.
  // Ici un exemple placeholder.
  const results = await prisma.vectorChunk.findMany({
    where: { document: { datasetId } },
    take: limit
  });
  return results.map(r => ({ id: r.id, content: r.content, meta: r.meta, score: 0.0 }));
}
EOF

cat > src/lib/rag/ingest.ts <<'EOF'
import { prisma } from "@/server/db";
import { chunkText } from "./chunk";
import { embedChunks } from "./embed";

export async function ingestDocument(documentId: string, text: string) {
  const chunks = chunkText(text);
  const embeddings = await embedChunks(chunks);
  for (let i = 0; i < chunks.length; i++) {
    await prisma.vectorChunk.create({
      data: {
        documentId,
        content: chunks[i],
        embedding: (embeddings[i] as any), // pgvector via Unsupported("vector")
        meta: {},
      },
    });
  }
  await prisma.document.update({ where: { id: documentId }, data: { status: "ready" } });
}
EOF

cat > src/lib/agents/runtime.ts <<'EOF'
import { prisma } from "@/server/db";
import { getProvider } from "@/lib/llm";

type RunAgentOpts = { agent: { id: string; graph: any; name: string }, runId: string };

export async function runAgent({ agent, runId }: RunAgentOpts) {
  const prov = await getProvider();
  const graph = agent.graph ?? { nodes: [] };
  const prompt: string = graph?.prompt ?? `Tu es l'agent ${agent.name}. Dis bonjour.`;
  const content = await prov.chat([{ role: "user", content: prompt }]);
  await prisma.run.update({ where: { id: runId }, data: { logs: { message: content } } });
}
EOF

# =========================
# API routes: Stripe, WhatsApp, Datasets, SSE
# =========================
mkdir -p src/app/api/stripe/webhook src/app/api/whatsapp/webhook src/app/api/datasets/upload src/app/api/agents/[id]/sse
cat > src/app/api/stripe/webhook/route.ts <<'EOF'
import Stripe from "stripe";
import { NextResponse } from "next/server";

export async function POST(req: Request) {
  const sig = req.headers.get("stripe-signature")!;
  const text = await req.text();
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? "", { apiVersion: "2024-06-20" as any });
  try {
    const event = stripe.webhooks.constructEvent(text, sig, process.env.STRIPE_WEBHOOK_SECRET ?? "");
    if (event.type === "customer.subscription.updated") {
      const sub = event.data.object as Stripe.Subscription;
      // TODO: mapper au plan interne + mettre à jour la table Subscription
    }
    return NextResponse.json({ received: true });
  } catch (err: any) {
    return new NextResponse(`Webhook Error: ${err.message}`, { status: 400 });
  }
}
EOF

cat > src/app/api/whatsapp/webhook/route.ts <<'EOF'
import { NextResponse } from "next/server";
export async function GET() {
  return NextResponse.json({ ok: true });
}
export async function POST(req: Request) {
  const body = await req.json().catch(()=>({}));
  // TODO: parser le message et router vers l'agent
  return NextResponse.json({ ok: true, received: body });
}
EOF

cat > src/app/api/datasets/upload/route.ts <<'EOF'
import { NextResponse } from "next/server";
import { prisma } from "@/server/db";

export async function POST() {
  // TODO: gérer multipart + upload S3 + ingestion
  const doc = await prisma.document.create({ data: { datasetId: "TOSET", path: "s3://...", size: 0, status: "pending" } });
  return NextResponse.json({ id: doc.id });
}
EOF

cat > src/app/api/agents/[id]/sse/route.ts <<'EOF'
import { NextResponse } from "next/server";

export async function GET() {
  const stream = new ReadableStream({
    start(controller) {
      const enc = new TextEncoder();
      controller.enqueue(enc.encode("event: ping\n"));
      controller.enqueue(enc.encode("data: connected\n\n"));
    },
  });
  return new NextResponse(stream, {
    headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", Connection: "keep-alive" }
  });
}
EOF

# =========================
# App (marketing + authed)
# =========================
mkdir -p src/app
cat > src/app/layout.tsx <<'EOF'
import "./../styles/globals.css";
import Link from "next/link";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const nav = [
    { href: "/", label: "Accueil" },
    { href: "/pricing", label: "Tarifs" },
    { href: "/docs", label: "Docs" },
    { href: "/dashboard", label: "Espace client" }
  ];
  return (
    <html lang="fr">
      <body className="min-h-screen bg-white text-gray-900 dark:bg-neutral-950 dark:text-gray-100">
        <header className="border-b">
          <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
            <Link href="/" className="font-bold">Zetsu AI</Link>
            <nav className="flex gap-6 text-sm">
              {nav.map(n => <Link key={n.href} href={n.href} className="hover:underline">{n.label}</Link>)}
            </nav>
          </div>
        </header>
        <main>{children}</main>
        <footer className="border-t mt-16">
          <div className="max-w-6xl mx-auto px-4 py-10 text-sm opacity-70">
            © {new Date().getFullYear()} Zetsu AI — RGPD-ready • Belgique • <a href="/privacy">Confidentialité</a>
          </div>
        </footer>
      </body>
    </html>
  );
}
EOF

cat > src/app/page.tsx <<'EOF'
export default function Page() {
  return (
    <div className="max-w-6xl mx-auto px-4 py-16">
      <div className="text-center space-y-6">
        <h1 className="text-4xl md:text-6xl font-extrabold">Des agents IA qui travaillent pendant que vous dormez.</h1>
        <p className="text-lg opacity-80">Prospection, prise de RDV, support et résumé de documents—déployés en 15 minutes.</p>
        <div className="flex gap-4 justify-center">
          <a className="px-6 py-3 rounded-md bg-black text-white dark:bg-white dark:text-black" href="/dashboard">Essayer gratuitement</a>
          <a className="px-6 py-3 rounded-md border" href="#demo">Voir la démo</a>
        </div>
      </div>

      <section className="mt-20 grid md:grid-cols-3 gap-8">
        <div><h3 className="font-semibold mb-2">1) Choisir un template</h3><p>Agents prêts à l’emploi: médical, juridique, e-commerce, B2B.</p></div>
        <div><h3 className="font-semibold mb-2">2) Connecter vos outils</h3><p>Gmail, Google Calendar, WhatsApp, Slack, Notion, etc.</p></div>
        <div><h3 className="font-semibold mb-2">3) Lancer & mesurer</h3><p>Suivez les runs, coûts, et RDV générés en temps réel.</p></div>
      </section>

      <section className="mt-16">
        <h2 className="text-2xl font-bold mb-4">Fonctionnalités clés</h2>
        <ul className="grid md:grid-cols-2 gap-4 list-disc pl-5">
          <li>Builder visuel (React Flow)</li>
          <li>WhatsApp/Email/Voix</li>
          <li>RAG PDF & recherche</li>
          <li>Intégrations: Gmail, GCal, Slack, Notion</li>
        </ul>
      </section>
    </div>
  );
}
EOF

mkdir -p src/app/pricing
cat > src/app/pricing/page.tsx <<'EOF'
const plans = [
  { name: "Free", price: "0€", features: ["1 agent", "100 runs/mois", "1 intégration", "200 Mo stockage", "watermark"] },
  { name: "Starter", price: "29€", features: ["3 agents", "2000 runs", "3 intégrations", "5 Go", "CRON, RAG basique"] },
  { name: "Pro", price: "99€", features: ["10 agents", "10000 runs", "10 intégrations", "50 Go", "WhatsApp/Telegram, Webhooks"] }
];
export default function Pricing() {
  return (
    <div className="max-w-6xl mx-auto px-4 py-16">
      <h1 className="text-4xl font-bold mb-10">Tarifs</h1>
      <div className="grid md:grid-cols-3 gap-6">
        {plans.map(p => (
          <div key={p.name} className="border rounded-lg p-6">
            <div className="text-xl font-semibold">{p.name}</div>
            <div className="text-3xl font-bold mt-2">{p.price}<span className="text-base font-normal"> / mois</span></div>
            <ul className="mt-4 space-y-2 text-sm">
              {p.features.map(f => <li key={f}>• {f}</li>)}
            </ul>
            <a href="/dashboard" className="mt-6 inline-block px-4 py-2 border rounded">Choisir</a>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

mkdir -p src/app/dashboard src/app/agents
cat > src/app/dashboard/page.tsx <<'EOF'
export default async function Dashboard() {
  return (
    <div className="max-w-6xl mx-auto px-4 py-10">
      <h1 className="text-3xl font-bold mb-6">Tableau de bord</h1>
      <div className="grid md:grid-cols-3 gap-4">
        <div className="border rounded p-4"><div className="text-sm opacity-70">Runs ce mois</div><div className="text-2xl font-bold">0</div></div>
        <div className="border rounded p-4"><div className="text-sm opacity-70">Agents</div><div className="text-2xl font-bold">0</div></div>
        <div className="border rounded p-4"><div className="text-sm opacity-70">Intégrations</div><div className="text-2xl font-bold">0</div></div>
      </div>
    </div>
  );
}
EOF

cat > src/app/agents/page.tsx <<'EOF'
export default function Agents() {
  return (
    <div className="max-w-6xl mx-auto px-4 py-10">
      <h1 className="text-3xl font-bold mb-6">Agents</h1>
      <p>Créez et éditez vos agents (builder visuel à venir).</p>
    </div>
  );
}
EOF

cat > src/app/not-found.tsx <<'EOF'
export default function NotFound() {
  return (
    <div className="min-h-[60vh] flex items-center justify-center text-center px-6">
      <div>
        <div className="text-7xl font-extrabold">404</div>
        <p className="mt-4 opacity-70">Page introuvable</p>
        <a href="/" className="mt-6 inline-block px-4 py-2 border rounded">Retour</a>
      </div>
    </div>
  );
}
EOF

# =========================
# README & Seed
# =========================
mkdir -p scripts
cat > README.md <<'EOF'
# Zetsu AI — SaaS d'Agents IA (starter prod-ready)

Stack: **Next.js 14 + TypeScript + tRPC + Prisma + PostgreSQL + BullMQ/Redis + S3 (MinIO) + NextAuth + Stripe + Resend + Tailwind**

## 🚀 Démarrage (Docker)

1) Copiez `.env.example` vers `.env` et ajustez si besoin.
2) Installez les deps: `npm i`
3) Initialisez la DB: `npx prisma db push`
4) Seed (optionnel): `npm run db:seed`
5) Lancez: `docker-compose up --build` puis http://localhost:3000

Services: Postgres (pgvector), Redis, MinIO, Mailpit (SMTP dev).

## 🧱 Inclus
- Auth magic link + Google
- Multi-tenant (Organisations/Memberships)
- Routers tRPC: auth/orgs/agents/runs/datasets/billing/admin
- Queue BullMQ + workers (agent runner + digest CRON)
- Abstraction LLM (OpenAI) + RAG stubs
- Webhooks Stripe/WhatsApp (squelettes)
- SSE simple
- Landing FR + Pricing + Dashboard

## ✅ À brancher rapidement
- Builder visuel React Flow
- Stripe Billing complet (plans/quotas)
- Upload S3 + ingestion RAG
- OAuth connecteurs (Gmail/GCal/Slack/Notion)
- Rate limit + masquage PII
- i18n (next-intl)

**APP_URL** pilote tout; aucun domaine n'est hardcodé.
EOF

cat > scripts/seed.ts <<'EOF'
import { prisma } from "../src/server/db";

async function main() {
  const org = await prisma.organisation.create({ data: { name: "Zetsu Demo Org" } });
  const agent = await prisma.agent.create({
    data: { orgId: org.id, name: "Agent Démo", graph: { prompt: "Présente-toi en 2 phrases." }, status: "active" }
  });
  console.log("Seeded:", { org: org.id, agent: agent.id });
}

main().then(()=>process.exit(0)).catch((e)=>{console.error(e);process.exit(1)});
EOF

echo "✅ Projet 'Zetsu AI' généré dans $(pwd)"
