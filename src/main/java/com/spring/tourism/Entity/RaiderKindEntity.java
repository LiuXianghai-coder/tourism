package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "raider_kind", schema = "public", catalog = "travel")
@IdClass(RaiderKindEntityPK.class)
public class RaiderKindEntity {
    private String raiderId;
    private int kindId;

    @Id
    @Column(name = "raider_id")
    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    @Id
    @Column(name = "kind_id")
    public int getKindId() {
        return kindId;
    }

    public void setKindId(int kindId) {
        this.kindId = kindId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        RaiderKindEntity that = (RaiderKindEntity) o;

        if (kindId != that.kindId) return false;
        if (!Objects.equals(raiderId, that.raiderId)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = raiderId != null ? raiderId.hashCode() : 0;
        result = 31 * result + kindId;
        return result;
    }
}
