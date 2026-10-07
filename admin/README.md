# Femora Admin

Next.js admin panel for Femora: lists every Firebase Authentication user and lets an admin activate or
deactivate accounts. Deactivating disables the Firebase account and revokes its sessions; the app checks
every 10 seconds (and whenever it is reopened) and signs a deactivated user out with a message.

## Run locally

    cp .env.example .env.local   # fill in the values
    npm install
    npm run dev

## Deploy to Vercel

    npx vercel login
    npx vercel link        # project root: admin
    npx vercel env add ADMIN_EMAIL production
    npx vercel env add ADMIN_PASSWORD production
    npx vercel env add FIREBASE_SERVICE_ACCOUNT production
    npx vercel --prod
