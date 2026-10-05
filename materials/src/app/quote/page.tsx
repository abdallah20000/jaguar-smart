import type { Metadata } from "next";
import { Suspense } from "react";
import { QuoteForm } from "@/components/QuoteForm";

export const metadata: Metadata = {
  title: "Request a quote",
  description: "Send your list of building materials, an Excel/PDF BOQ or a photo. Jaguar Smart prices it for your area and replies on WhatsApp.",
  alternates: { canonical: "/materials/quote/" },
};

export default function QuotePage() {
  return <Suspense><QuoteForm /></Suspense>;
}
