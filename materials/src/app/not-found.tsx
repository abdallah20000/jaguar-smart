import Link from "next/link";

export default function NotFound() {
  return (
    <div className="wrap max-w-xl py-20 text-center">
      <h1 className="m-0 text-3xl font-semibold">Page not found</h1>
      <p className="text-muted">This product or page isn&apos;t available.</p>
      <Link href="/" className="btn btn-ink mt-4">Back to materials</Link>
    </div>
  );
}
