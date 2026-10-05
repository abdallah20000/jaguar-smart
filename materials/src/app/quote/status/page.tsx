import type { Metadata } from "next";
import { Suspense } from "react";
import { QuoteStatus } from "@/components/QuoteStatus";

export const metadata: Metadata = { title: "Your quote request", robots: { index: false, follow: false } };

export default function QuoteStatusPage() {
  return <Suspense><QuoteStatus /></Suspense>;
}
