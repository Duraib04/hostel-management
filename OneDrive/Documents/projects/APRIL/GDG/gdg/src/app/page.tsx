import Link from "next/link";

export default function Home() {
  return (
    <main className="mx-auto w-full max-w-6xl flex-1 px-5 py-7 sm:px-7 md:px-10">
      <header className="rise-in mb-8 flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-[#d7c4aa] bg-[#fff7e9]/80 px-5 py-4 backdrop-blur-sm">
        <div>
          <p className="text-xs font-semibold tracking-[0.2em] text-[#7a2e20]">
            SOUTH INDIAN FOLK AND CULTURAL DANCE
          </p>
          <h1 className="text-2xl font-semibold text-[#1f222b] sm:text-3xl">
            Nadana Arangam
          </h1>
        </div>
        <nav className="flex flex-wrap gap-2 text-sm font-semibold">
          <Link
            className="rounded-full border border-[#cfa983] px-4 py-2 text-[#7a2e20] hover:bg-[#ffe7d2]"
            href="/dashboard"
          >
            Student Dashboard
          </Link>
          <Link
            className="rounded-full border border-[#5a918f] px-4 py-2 text-[#0f6a66] hover:bg-[#def2f0]"
            href="/instructor"
          >
            Instructor Dashboard
          </Link>
        </nav>
      </header>

      <section className="rise-in soft-card mb-8 grid gap-7 p-6 md:grid-cols-[1.2fr_1fr] md:p-8">
        <div>
          <p className="stat-pill inline-flex">Beginner Journey Program</p>
          <h2 className="mt-4 text-3xl leading-tight text-[#1f222b] sm:text-5xl">
            Learn rhythm, posture, and storytelling through living dance traditions.
          </h2>
          <p className="mt-4 max-w-xl text-base leading-7 text-[#4e535a]">
            Start from basics with guided video lessons in Kummi, Oyilattam,
            Karagattam, and Kavadi Aattam. Every module blends technique,
            cultural context, and weekly practice goals.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link
              href="/dashboard"
              className="rounded-full bg-[#a33e2b] px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-[#7a2e20]"
            >
              Start Learning
            </Link>
            <button className="rounded-full border border-[#d9bda0] px-5 py-3 text-sm font-semibold text-[#7a2e20] transition hover:bg-[#fff2df]">
              Explore Dance Library
            </button>
          </div>
        </div>
        <div className="rounded-2xl border border-[#e2ccb3] bg-gradient-to-b from-[#fff1de] to-[#f9dfc4] p-5">
          <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[#7a2e20]">
            This Week
          </p>
          <ul className="mt-4 space-y-3 text-sm text-[#32353b]">
            <li className="soft-card p-3">
              Kummi Foundations: 3 video lessons and 1 rhythm drill
            </li>
            <li className="soft-card p-3">
              Quiz: Folk dance roots in Tamil Nadu and Kerala
            </li>
            <li className="soft-card p-3">
              Assignment: 45-second footwork practice upload
            </li>
          </ul>
        </div>
      </section>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[
          ["12+", "Structured beginner modules"],
          ["40+", "Step-by-step lesson videos"],
          ["4", "Core folk dance tracks"],
          ["2", "Role-based dashboards"],
        ].map(([value, label], index) => (
          <article
            key={label}
            className="soft-card rise-in p-4"
            style={{ animationDelay: `${index * 90}ms` }}
          >
            <p className="text-3xl font-semibold text-[#7a2e20]">{value}</p>
            <p className="mt-2 text-sm text-[#4e535a]">{label}</p>
          </article>
        ))}
      </section>
    </main>
  );
}
