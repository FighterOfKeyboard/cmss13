import { Fragment } from 'react';
import { useBackend } from '../backend';
import { Button, Section, Flex, NoticeBox, Collapsible, Divider, Box } from '../components';
import { Window } from '../layouts';

export const OperationControl = (_props) => {
  const { act, data } = useBackend();

  const worldTime = data.worldtime;
  const messages = data.messages;

  const SelectedSquad = data.selected_squad;
  const ShowCommandSquad = data.show_command_squad;


  const selectedLZ = data.selected_LZ;/*(data.selected_LZ !== 'lz1' || data.selected_LZ !== 'lz2');*/
  


  const canAnnounce = data.endtime < worldTime; // announcement

  let canSelectLZ;
  if (selectedLZ === '' || selectedLZ === null) {
    canSelectLZ = true;
  }
  else {
    canSelectLZ = false;
  }


  let squadColor;
  if (SelectedSquad === 'Intel') {
    squadColor = 'green';
  }
  if (SelectedSquad === 'Alpha') {
    squadColor = 'red';
  }
  if (SelectedSquad === 'Bravo') {
    squadColor = 'yellow';
  }
  if (SelectedSquad === 'Charlie') {
    squadColor = 'purple';
  }
  if (SelectedSquad === 'Delta') {
    squadColor = 'blue';
  }
  if (SelectedSquad === 'Echo') {
    squadColor = 'teal';
  }
  let squadText;
  if (!ShowCommandSquad) {
    squadText = SelectedSquad;
  }
  else {
    squadText = 'Command';
    squadColor = 'black';
  }

  return (
    <Window width={450} height={700}>
      <Window.Content scrollable>
        <Section title="Operation Control">
          <Flex height="100%" direction="column">
            <Flex.Item>
              {!canAnnounce && (
                <Button color="bad" warning={1} fluid={1} icon="ban">
                  Announcement recharging:{' '}
                  {Math.ceil((data.endtime - data.worldtime) / 10)} secs
                </Button>
              )}
              {!!canAnnounce && (
                <Button
                  fluid={1}
                  icon="bullhorn"
                  title="Make an announcement"
                  content="Make an announcement"
                  onClick={() => act('announce')}
                  disabled={!canAnnounce}
                />
              )}
            </Flex.Item>
            <Flex.Item>
                <Button
                  fluid={1}
                  icon="map"
                  title="Tacmap"
                content="Tacmap"
                  onClick={() => act('mapview')}
                />
            </Flex.Item>
            <Flex.Item>
              <Button
                fluid={1}
                icon="arrow-up-from-bracket"
                title="Designate Echo Squad"
                content="Designate Echo Squad"
                onClick={() => act('activate_echo')}
              />
            </Flex.Item>
            <Flex.Item>
             
              {!!canSelectLZ && (
                <Button
                  fluid={1}
                  icon="plane-arrival"
                  title="Designate Primary LZ"
                  content="Designate Primary LZ"
                  color = 'bad'
                  onClick={() => act('selectlz')}
                  disabled={!canSelectLZ}
                />
              )}
            </Flex.Item>
            <Section title="Squad Selection">
              <Flex.Item>
                <Button
                  fluid={1}
                  color={squadColor}
                  icon="triangle-exclamation"
                  onClick={() => act('pick_squad')}>
                  {squadText}
                </Button>
              </Flex.Item>
            </Section>
          </Flex>
        </Section>
        {messages && (
          <>
            <Divider />
            <Collapsible title="Messages">
              <Flex>
                {messages.map((entry) => {
                  return (
                    <Flex.Item key={entry} grow>
                      <Section
                        title={entry.title}
                        buttons={
                          <Button
                            content={'Delete message'}
                            color="red"
                            icon="trash"
                            onClick={() =>
                              act('delmessage', { number: entry.number })
                            }
                          />
                        }>
                        <Box>{entry.text}</Box>
                      </Section>
                    </Flex.Item>
                  );
                })}
              </Flex>
            </Collapsible>
          </>
        )}
      </Window.Content>
    </Window>
  );
};
