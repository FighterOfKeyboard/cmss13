import { Fragment } from 'react';
import { useBackend, useSharedState } from '../backend';
import { Button, Section, Stack, Tabs, Table, Box, Input, NumberInput, LabeledControls, Divider, Collapsible, Flex, NoticeBox  } from '../components';;
import { Window } from '../layouts';

export const OperationControl = (_props) => {
  const { act, data } = useBackend();

  const worldTime = data.worldtime;
  const messages = data.messages;

  const SelectedSquad = data.selected_squad;
  const ShowCommandSquad = data.show_command_squad;

  const canAnnounce = data.endtime < worldTime; // announcement

  const {
    leaders_alive,
    ftl_alive,
    ftl_count,
    specialist_type,
    spec_alive,
    smart_alive,
    smart_count,
    spec_count,
    medic_count,
    medic_alive,
    engi_alive,
    engi_count,
    living_count,
    total_deployed,
  } = data;

  const sortByRole = (a, b) => {
    a = a.role;
    b = b.role;
    const roleValues = {
      'Squad Leader': 10,
      'Fireteam Leader': 9,
      'Weapons Specialist': 8,
      'Smartgunner': 7,
      'Hospital Corpsman': 6,
      'Combat Technician': 5,
      'Rifleman': 4,
    };
    let valueA = roleValues[a];
    let valueB = roleValues[b];
    if (a.includes('Weapons Specialist')) {
      valueA = roleValues['Weapons Specialist'];
    }
    if (b.includes('Weapons Specialist')) {
      valueB = roleValues['Weapons Specialist'];
    }
    if (!valueA && !valueB) return 0; // They're both unknown
    if (!valueA) return 1; // B is defined but A is not
    if (!valueB) return -1; // A is defined but B is not

    if (valueA > valueB) return -1; // A is more important
    if (valueA < valueB) return 1; // B is more important

    return 0; // They're equal
  };

  let { marines, squad_leader } = data;

  const [hidden_marines, setHiddenMarines] = useSharedState(
    'hidden_marines',
    []
  );

  const [showHiddenMarines, setShowHiddenMarines] = useSharedState(
    'showhidden',
    false
  );
  const [showDeadMarines, setShowDeadMarines] = useSharedState(
    'showdead',
    false
  );

  const [marineSearch, setMarineSearch] = useSharedState('marinesearch', null);

  let determine_status_color = (status) => {
    let conscious = status.includes('Conscious');
    let unconscious = status.includes('Unconscious');

    let state_color = 'red';
    if (conscious) {
      state_color = 'green';
    } else if (unconscious) {
      state_color = 'yellow';
    }
    return state_color;
  };

  let toggle_marine_hidden = (ref) => {
    if (!hidden_marines.includes(ref)) {
      setHiddenMarines([...hidden_marines, ref]);
    } else {
      let array_copy = [...hidden_marines];
      let index = array_copy.indexOf(ref);
      if (index > -1) {
        array_copy.splice(index, 1);
      }
      setHiddenMarines(array_copy);
    }
  };

  let location_filter;
  if (data.z_hidden === 2) {
    location_filter = 'groundside';
  } else if (data.z_hidden === 1) {
    location_filter = 'shipside';
  } else {
    location_filter = 'all';
  }

  const selectedLZ = data.selected_LZ;/*(data.selected_LZ !== 'lz1' || data.selected_LZ !== 'lz2');*/
  


 

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
  if (SelectedSquad === 'Foxtrot') {
    squadColor = 'brown';
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
    <Window width={600} height={800}>
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
                  icon="users-line"
                  onClick={() => act('pick_squad')}>
                  {squadText}
                </Button>
              </Flex.Item>
              <NoticeBox color={squadColor} warning={1} textAlign="center">
                Living count: {living_count}; Total deployed: {total_deployed};
                Medic count: {medic_count}; Engineer count: {engi_count};
              </NoticeBox>
            </Section>
            <Section title="Squad Marines">
              <Input
                fluid
                placeholder="Search.."
                mb="4px"
                value={marineSearch}
                onInput={(e, value) => setMarineSearch(value)}
              />
              <Table>
                <Table.Row bold fontSize="14px">
                  <Table.Cell textAlign="center">Name</Table.Cell>
                  <Table.Cell textAlign="center">Role</Table.Cell>
                  <Table.Cell textAlign="center" collapsing>
                    State
                  </Table.Cell>
                  <Table.Cell textAlign="center">Location</Table.Cell>
                  <Table.Cell textAlign="center" collapsing fontSize="12px">
                    SL Dist.
                  </Table.Cell>
                  <Table.Cell textAlign="center" />
                </Table.Row>
                {squad_leader && (
                  <Table.Row key="index" bold>
                    <Table.Cell collapsing p="2px">
                      {(squad_leader.has_helmet && (
                        <Button
                          onClick={() =>
                            act('watch_camera', { target_ref: squad_leader.ref })
                          }>
                          {squad_leader.name}
                        </Button>
                      )) || <Box color="yellow">{squad_leader.name} (NO HELMET)</Box>}
                    </Table.Cell>
                    <Table.Cell p="2px">{squad_leader.role}</Table.Cell>
                    <Table.Cell
                      p="2px"
                      color={determine_status_color(squad_leader.state)}>
                      {squad_leader.state}
                    </Table.Cell>
                    <Table.Cell p="2px">{squad_leader.area_name}</Table.Cell>
                    <Table.Cell p="2px" collapsing>
                      {squad_leader.distance}
                    </Table.Cell>
                    <Table.Cell />
                  </Table.Row>
                )}
                {marines &&
                  marines
                    .sort(sortByRole)
                    .filter((marine) => {
                      if (marineSearch) {
                        const searchableString = String(marine.name).toLowerCase();
                        return searchableString.match(new RegExp(marineSearch, 'i'));
                      }
                      return marine;
                    })
                    .map((marine, index) => {
                      if (squad_leader) {
                        if (marine.ref === squad_leader.ref) {
                          return;
                        }
                      }
                      if (hidden_marines.includes(marine.ref) && !showHiddenMarines) {
                        return;
                      }
                      if (marine.state === 'Dead' && !showDeadMarines) {
                        return;
                      }

                      return (
                        <Table.Row key={index}>
                          <Table.Cell collapsing p="2px">
                            {(marine.has_helmet && (
                              <Button
                                onClick={() =>
                                  act('watch_camera', { target_ref: marine.ref })
                                }>
                                {marine.name}
                              </Button>
                            )) || <Box color="yellow">{marine.name} (NO HELMET)</Box>}
                          </Table.Cell>
                          <Table.Cell p="2px">{marine.role}</Table.Cell>
                          <Table.Cell
                            p="2px"
                            color={determine_status_color(marine.state)}>
                            {marine.state}
                          </Table.Cell>
                          <Table.Cell p="2px">{marine.area_name}</Table.Cell>
                          <Table.Cell p="2px" collapsing>
                            {marine.distance}
                          </Table.Cell>
                        </Table.Row>
                      );
                    })}
              </Table>
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
