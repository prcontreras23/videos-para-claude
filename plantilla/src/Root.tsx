import "./index.css";
import { Composition } from "remotion";
import { Prueba } from "./Prueba";

// Cada video nuevo es una carpeta en src/ y una línea aquí.
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition id="Prueba" component={Prueba} durationInFrames={90} fps={30} width={1080} height={1920} />
    </>
  );
};
