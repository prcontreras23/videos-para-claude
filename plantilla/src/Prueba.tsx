// Composición mínima para comprobar que Remotion, las fuentes y el render funcionan.
import React from "react";
import { loadFont } from "@remotion/google-fonts/DMSans";
import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";

const { fontFamily } = loadFont("normal", { weights: ["700"], subsets: ["latin", "latin-ext"] });

export const Prueba: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 14 } });
  return (
    <AbsoluteFill style={{ background: "linear-gradient(170deg,#02365e,#011a30)", justifyContent: "center", alignItems: "center", fontFamily }}>
      <div style={{ color: "#fff", fontSize: 96, transform: `scale(${s})`, textAlign: "center" }}>Todo listo</div>
      <div style={{ color: "#5BC0C9", fontSize: 44, marginTop: 30, opacity: s }}>Videos con Remotion</div>
    </AbsoluteFill>
  );
};
