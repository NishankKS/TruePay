// Genkit `auditSummary` (PRD §9, Should): 3-sentence AI summary on the audit report. Hidden in the UI if it fails.
// Deploy: firebase functions:secrets:set GEMINI_API_KEY && firebase deploy --only functions
import { genkit, z } from 'genkit';
import { googleAI } from '@genkit-ai/google-genai';
import { onCallGenkit } from 'firebase-functions/https';
import { defineSecret } from 'firebase-functions/params';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const geminiKey = defineSecret('GEMINI_API_KEY');
initializeApp();
const ai = genkit({ plugins: [googleAI()] });

export const auditSummaryFlow = ai.defineFlow(
  { name: 'auditSummary', inputSchema: z.object({}).passthrough().optional(), outputSchema: z.string() },
  async () => {
    const snap = await getFirestore().collection('events').orderBy('ts').limit(500).get();
    // Events are already IBAN-masked; only firewall/human decisions go to the model.
    const lines = snap.docs
      .map((d) => d.data())
      .filter((e) => e.verdict === 'ALLOW' || e.verdict === 'DENY')
      .map((e) => `${e.run_id} ${e.actor} ${e.layer ?? ''} ${e.verdict} ${e.title} ${(e.codes ?? []).join(' ')}`);
    const { text } = await ai.generate({
      model: googleAI.model(process.env.WORKER_MODEL ?? 'gemini-3.8-flash'),
      config: { temperature: 0 },
      prompt:
        'Summarize this payment-firewall audit log for a CFO in exactly 3 sentences: what was paid, what was ' +
        'blocked and why, and which identity was revoked if any. Facts only.\n\n' + lines.join('\n'),
    });
    return text;
  },
);

export const auditSummary = onCallGenkit(
  { secrets: [geminiKey], region: 'europe-west3', authPolicy: (auth) => !!auth?.token?.email },
  auditSummaryFlow,
);
