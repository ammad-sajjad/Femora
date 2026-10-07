export function Logo({ size = 36 }: { size?: number }) {
  return (
    <div
      className="brand-gradient grid place-items-center rounded-xl text-white shadow-[0_6px_16px_-6px_rgba(158,27,70,0.6)]"
      style={{ width: size, height: size }}
    >
      <svg width={size * 0.55} height={size * 0.55} viewBox="0 0 24 24" fill="none" aria-hidden>
        <path
          d="M12 20.5s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7.6a4.3 4.3 0 0 1 7.5 2.7c0 5.6-7.5 10.2-7.5 10.2Z"
          fill="currentColor"
        />
      </svg>
    </div>
  );
}
