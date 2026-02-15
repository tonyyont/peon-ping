import { Composition } from "remotion";
import { SovietEngineerPreview } from "./SovietEngineerPreview";
import { KerriganPreview } from "./KerriganPreview";
import { SopranosPreview } from "./SopranosPreview";
import { GladosPreview } from "./GladosPreview";
import { SheogorathPreview } from "./SheogorathPreview";
import { AxePreview } from "./AxePreview";
import { BattlecruiserPreview } from "./BattlecruiserPreview";
import { DukeNukemPreview } from "./DukeNukemPreview";
import { KirovPreview } from "./KirovPreview";
import { HelldiversPreview } from "./HelldiversPreview";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="SovietEngineerPreview"
        component={SovietEngineerPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="KerriganPreview"
        component={KerriganPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="SopranosPreview"
        component={SopranosPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="GladosPreview"
        component={GladosPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="SheogorathPreview"
        component={SheogorathPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="AxePreview"
        component={AxePreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="BattlecruiserPreview"
        component={BattlecruiserPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="DukeNukemPreview"
        component={DukeNukemPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="KirovPreview"
        component={KirovPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="HelldiversPreview"
        component={HelldiversPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
    </>
  );
};
